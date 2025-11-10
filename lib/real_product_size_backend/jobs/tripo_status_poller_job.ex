defmodule RealProductSizeBackend.Jobs.TripoStatusPollerJob do
  @moduledoc """
  Oban worker for polling TripoAI task status until completion.
  Uses snooze mechanism to retry every 10 seconds for up to 10 minutes.
  """

  use Oban.Worker, queue: :tripo_status_poll, max_attempts: 60

  require Logger
  alias RealProductSizeBackend.{TripoGenerationLogs, Products}
  alias RealProductSizeBackend.Jobs.DownloadTripoModelJob

  @finch_name :"RealProductSizeBackend.Finch"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => product_id, "task_id" => task_id}, attempt: attempt}) do
    Logger.info("Polling TripoAI task status for task_id: #{task_id}, attempt: #{attempt}")

    case fetch_task_status(task_id) do
      {:ok, response_data} ->
        status = response_data["status"]
        Logger.info("Task #{task_id} status: #{status}, progress: #{response_data["progress"]}")

        # Update log with latest response
        TripoGenerationLogs.update_log_status(task_id, status, response_data)

        case status do
          "success" ->
            handle_success(product_id, task_id, response_data)

          "failed" ->
            handle_failure(product_id, task_id, response_data)

          "cancelled" ->
            handle_failure(product_id, task_id, response_data)

          status when status in ["processing", "queued"] ->
            # Continue polling - snooze for 10 seconds
            Logger.info("Task #{task_id} still #{status}, will retry in 10 seconds")
            {:snooze, 10}

          _ ->
            Logger.warning("Unknown status '#{status}' for task #{task_id}")
            {:snooze, 10}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch task status for #{task_id}: #{inspect(reason)}")

        # If we've reached max attempts, mark as failed
        if attempt >= 60 do
          handle_timeout(product_id, task_id)
        else
          # Otherwise retry
          {:snooze, 10}
        end
    end
  end

  defp fetch_task_status(task_id) do
    config = Application.get_env(:real_product_size_backend, :tripo, [])
    api_url = config[:api_url] || "https://api.tripo3d.ai"
    api_key = config[:api_key]
    url = "#{api_url}/v2/openapi/task/#{task_id}"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    Logger.debug("Fetching task status from: #{url}")

    case Finch.build(:get, url, headers)
         |> Finch.request(@finch_name, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"code" => 0, "data" => data}} ->
            {:ok, data}

          {:ok, %{"code" => code, "message" => message}} ->
            Logger.error("TripoAI API error: code=#{code}, message=#{message}")
            {:error, "API error: #{message}"}

          {:error, decode_error} ->
            Logger.error("Failed to decode TripoAI response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("TripoAI API returned HTTP #{status}: #{body}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_success(product_id, task_id, response_data) do
    Logger.info("Task #{task_id} completed successfully, queuing download job")

    # Update product status
    Products.update_product_generation_status(product_id, "downloading")

    # Queue download job
    %{
      product_id: product_id,
      task_id: task_id,
      pbr_model_url: get_in(response_data, ["result", "pbr_model", "url"]),
      rendered_image_url: get_in(response_data, ["result", "rendered_image", "url"])
    }
    |> DownloadTripoModelJob.new()
    |> Oban.insert()

    :ok
  end

  defp handle_failure(product_id, task_id, response_data) do
    error_message = response_data["error"] || response_data["status"]
    Logger.error("Task #{task_id} failed: #{error_message}")

    # Update product status
    Products.update_product_generation_status(product_id, "failed")

    # Broadcast failure
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product_updates:#{product_id}",
      {:model_failed, product_id, %{error: error_message}}
    )

    {:error, error_message}
  end

  defp handle_timeout(product_id, task_id) do
    Logger.error("Task #{task_id} timed out after maximum polling attempts")

    # Update product status
    Products.update_product_generation_status(product_id, "timeout")

    # Update log with timeout error
    TripoGenerationLogs.update_log_status(task_id, "timeout", %{
      "error" => "Task timed out after maximum polling attempts"
    })

    # Broadcast failure
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product_updates:#{product_id}",
      {:model_failed, product_id, %{error: "timeout"}}
    )

    {:error, :timeout}
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(30)
end
