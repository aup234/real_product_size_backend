defmodule RealProductSizeBackend.Jobs.DownloadTripoModelJob do
  @moduledoc """
  Oban worker for downloading generated 3D models and preview images from TripoAI.
  Saves files locally and updates the database with local paths.
  """

  use Oban.Worker, queue: :tripo_download, max_attempts: 3

  require Logger
  alias RealProductSizeBackend.{TripoGenerationLogs, Products}

  @finch_name :"RealProductSizeBackend.Finch"

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "product_id" => product_id,
          "task_id" => task_id,
          "pbr_model_url" => pbr_model_url,
          "rendered_image_url" => rendered_image_url
        }
      }) do
    Logger.info("Starting download for task #{task_id}, product #{product_id}")

    # Create product directory if it doesn't exist
    product_dir = Path.join([Application.app_dir(:real_product_size_backend, "priv"), "static", "3d", "products", product_id])
    File.mkdir_p!(product_dir)

    with {:ok, model_path} <- download_file(pbr_model_url, product_dir, "model.glb"),
         {:ok, _image_path} <- download_file(rendered_image_url, product_dir, "preview.webp"),
         {:ok, _log} <- update_log_and_product(product_id, task_id, model_path) do
      Logger.info("Successfully downloaded and saved 3D model for product #{product_id}")
      broadcast_model_ready(product_id, model_path)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to download model for product #{product_id}: #{inspect(reason)}")
        Products.update_product_generation_status(product_id, "download_failed")
        {:error, reason}
    end
  end

  defp download_file(url, target_dir, filename) do
    Logger.info("Downloading file from: #{url}")
    target_path = Path.join(target_dir, filename)

    config = Application.get_env(:real_product_size_backend, :tripo, [])
    timeout = config[:download_timeout] || 120_000

    case Finch.build(:get, url)
         |> Finch.request(@finch_name, receive_timeout: timeout) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Downloaded #{byte_size(body)} bytes, saving to: #{target_path}")

        case File.write(target_path, body) do
          :ok ->
            {:ok, target_path}

          {:error, reason} ->
            Logger.error("Failed to write file to #{target_path}: #{inspect(reason)}")
            {:error, reason}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Download failed with HTTP #{status}: #{String.slice(body, 0, 200)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("Download request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp update_log_and_product(product_id, task_id, _model_path) do
    # Get relative path for serving
    relative_path = "/3d/products/#{product_id}/model.glb"

    # Update generation log
    case TripoGenerationLogs.update_log_with_local_path(task_id, relative_path) do
      {:ok, _log} ->
        # Update product with model URL and status
        case Products.get_product!(product_id) do
          nil ->
            {:error, :product_not_found}

          product ->
            Products.update_product(product, %{
              ar_model_url: relative_path,
              model_generation_status: "completed",
              model_generated_at: DateTime.utc_now()
            })
        end

      error ->
        error
    end
  end

  defp broadcast_model_ready(product_id, _model_path) do
    # Broadcast to specific product channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product:#{product_id}",
      {:model_generated, %{model_url: "/3d/products/#{product_id}/model.glb"}}
    )

    # Broadcast to general product updates channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product_updates:#{product_id}",
      {:model_ready, product_id, %{model_url: "/3d/products/#{product_id}/model.glb"}}
    )

    Logger.info("Broadcasted model_ready event for product #{product_id}")
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(3)

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 10s, 20s, 40s
    :math.pow(2, attempt) * 10 |> round()
  end
end
