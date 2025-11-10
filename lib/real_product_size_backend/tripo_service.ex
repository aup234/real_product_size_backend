defmodule RealProductSizeBackend.TriPoService do
  @moduledoc """
  Service for generating 3D models using TripoAI v2 API
  """

  require Logger
  alias RealProductSizeBackend.{Products, TripoGenerationLogs}
  alias RealProductSizeBackend.Jobs.TripoStatusPollerJob

  @finch_name :"RealProductSizeBackend.Finch"

  defp get_tripo_config do
    Application.get_env(:real_product_size_backend, :tripo, [])
  end

  @doc """
  Generate 3D model for a product using TripoAI API
  """
  def generate_3d_model(product_id) do
    Logger.info("Starting 3D model generation for product #{product_id}")

    # Check production configuration
    production_config = Application.get_env(:real_product_size_backend, :production, %{})
    debug_config = Application.get_env(:real_product_size_backend, :debug, %{})

    cond do
      # Production mode - check if 3D model generation is enabled
      production_config[:enable_3d_model_generation] == false ->
        Logger.info("3D model generation disabled in production for product #{product_id}")
        update_product_generation_status(product_id, "disabled")
        {:error, :disabled_in_production}

      # Debug mode - check if explicitly disabled
      debug_config[:skip_3d_model_generation] == true ->
        Logger.info("Skipping 3D model generation for product #{product_id} (debug mode)")
        update_product_generation_status(product_id, "skipped")
        {:error, :skipped_for_debug}

      # Check if TriPo service is enabled
      !enabled?() ->
        Logger.info("TriPo service not enabled for product #{product_id}")
        update_product_generation_status(product_id, "service_disabled")
        {:error, :service_disabled}

      # Proceed with generation
      true ->
        # Queue the job for background processing
        queue_3d_model_generation_job(product_id)
    end
  end

  def queue_3d_model_generation_job(product_id) do
    case RealProductSizeBackend.TripoGenerationWorker.new(%{"product_id" => product_id})
         |> Oban.insert() do
      {:ok, job} ->
        Logger.info("Queued 3D model generation job #{job.id} for product #{product_id}")
        update_product_generation_status(product_id, "queued")
        {:ok, %{job_id: job.id, status: "queued"}}

      {:error, reason} ->
        Logger.error("Failed to queue 3D model generation job for product #{product_id}: #{inspect(reason)}")
        update_product_generation_status(product_id, "queue_failed")
        {:error, reason}
    end
  end

  def process_3d_model_generation(product_id) do
    Logger.info("Processing 3D model generation for product #{product_id}")

    # Broadcast generation started
    broadcast_generation_started(product_id)

    with {:ok, product} <- get_product_with_images(product_id),
         {:ok, image_url} <- get_product_image_url(product),
         {:ok, task_id} <- submit_task_to_tripo(product_id, image_url),
         {:ok, _job} <- queue_status_poller(product_id, task_id) do
      Logger.info("Successfully submitted 3D model generation task #{task_id} for product #{product_id}")
      {:ok, %{task_id: task_id}}
    else
      {:error, reason} ->
        Logger.error(
          "TriPo 3D model generation failed for product #{product_id}: #{inspect(reason)}"
        )

        update_product_generation_status(product_id, "failed")
        broadcast_model_failed(product_id, %{error: reason})
        {:error, reason}
    end
  end

  @doc """
  Check if TriPo is enabled
  """
  def enabled? do
    debug_config = Application.get_env(:real_product_size_backend, :debug, %{})

    # Respect both global TriPo config and debug skip setting
    get_tripo_config()[:enabled] &&
      !debug_config[:skip_3d_model_generation]
  end

  @doc """
  Update product model generation status
  """
  def update_product_generation_status(product_id, status) do
    Products.update_product_generation_status(product_id, status)
  end

  # Private functions

  defp get_product_with_images(product_id) do
    case Products.get_product!(product_id) do
      nil -> {:error, :product_not_found}
      product -> {:ok, product}
    end
  end

  defp get_product_image_url(product) do
    cond do
      # First try primary image
      is_binary(product.primary_image_url) and byte_size(product.primary_image_url) > 0 ->
        {:ok, product.primary_image_url}

      # Then try first image from image_urls array
      is_list(product.image_urls) and length(product.image_urls) > 0 ->
        {:ok, List.first(product.image_urls)}

      # No images available
      true ->
        Logger.error("Product #{product.id} has no images available for 3D generation")
        {:error, :no_images_available}
    end
  end

  defp submit_task_to_tripo(product_id, image_url) do
    Logger.info("Submitting 3D generation task to TripoAI for product #{product_id}")
    Logger.info("Using image URL: #{image_url}")

    config = get_tripo_config()
    api_url = config[:api_url] || "https://api.tripo3d.ai"
    api_key = config[:api_key]
    url = "#{api_url}/v2/openapi/task"

    # Extract file type from URL
    file_type = extract_file_type_from_url(image_url)

    request_payload = %{
      "type" => "image_to_model",
      "file" => %{
        "type" => file_type,
        "url" => image_url
      }
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = Jason.encode!(request_payload)

    Logger.debug("Sending request to: #{url}")
    Logger.debug("Request payload: #{inspect(request_payload)}")

    case Finch.build(:post, url, headers, body)
         |> Finch.request(@finch_name, receive_timeout: config[:timeout] || 60_000) do
      {:ok, %{status: 200, body: response_body}} ->
        Logger.debug("TripoAI response: #{response_body}")

        case Jason.decode(response_body) do
          {:ok, %{"code" => 0, "data" => %{"task_id" => task_id}}} ->
            Logger.info("Successfully submitted task, got task_id: #{task_id}")

            # Create log entry
            case TripoGenerationLogs.create_log(product_id, task_id, request_payload) do
              {:ok, _log} ->
                # Update product with task_id
                case Products.get_product!(product_id) do
                  nil -> {:error, :product_not_found}
                  product -> Products.update_product(product, %{tripo_task_id: task_id})
                end

                {:ok, task_id}

              {:error, reason} ->
                Logger.error("Failed to create log entry: #{inspect(reason)}")
                {:ok, task_id}  # Continue anyway, log is not critical
            end

          {:ok, %{"code" => code, "message" => message}} ->
            Logger.error("TripoAI API error: code=#{code}, message=#{message}")
            {:error, "API error: #{message}"}

          {:ok, response} ->
            Logger.error("Unexpected response format: #{inspect(response)}")
            {:error, :unexpected_response_format}

          {:error, decode_error} ->
            Logger.error("Failed to decode response: #{inspect(decode_error)}")
            {:error, :json_decode_error}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("TripoAI API returned HTTP #{status}: #{body}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("Request to TripoAI failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp queue_status_poller(product_id, task_id) do
    Logger.info("Queuing status poller for task #{task_id}")

    %{
      product_id: product_id,
      task_id: task_id
    }
    |> TripoStatusPollerJob.new()
    |> Oban.insert()
  end

  defp broadcast_generation_started(product_id) do
    # Broadcast to specific product channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product:#{product_id}",
      {:generation_started, %{started_at: DateTime.utc_now(), product_id: product_id}}
    )

    # Broadcast to general product updates channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product_updates:#{product_id}",
      {:generation_started, product_id}
    )
  end

  defp broadcast_model_failed(product_id, error_data) do
    # Broadcast to specific product channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product:#{product_id}",
      {:model_failed, Map.put(error_data, :product_id, product_id)}
    )

    # Broadcast to general product updates channel
    Phoenix.PubSub.broadcast(
      RealProductSizeBackend.PubSub,
      "product_updates:#{product_id}",
      {:model_failed, product_id, error_data}
    )
  end

  defp extract_file_type_from_url(url) do
    url
    |> String.downcase()
    |> URI.parse()
    |> Map.get(:path, "")
    |> Path.extname()
    |> String.trim_leading(".")
    |> case do
      "" -> "jpg"  # Default fallback
      "jpg" -> "jpg"
      "jpeg" -> "jpg"
      "png" -> "png"
      "webp" -> "webp"
      ext -> ext
    end
  end
end
