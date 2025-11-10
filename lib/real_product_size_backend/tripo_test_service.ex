defmodule RealProductSizeBackend.TripoTestService do
  @moduledoc """
  Service for testing TripoAI 3D model generation directly with manual images
  """

  require Logger
  alias RealProductSizeBackend.CircuitBreaker

  @finch_name :"RealProductSizeBackend.Finch"
  @manual_images_path "priv/static/product_imgs/manual"
  @test_models_path "priv/static/3d/test"

  defp get_tripo_config do
    Application.get_env(:real_product_size_backend, :tripo, [])
  end

  @doc """
  Test TripoAI API connectivity with detailed logging
  """
  def test_api_connectivity_detailed do
    api_url = get_tripo_config()[:api_url]
    api_key = get_tripo_config()[:api_key]

    Logger.info("=== TripoAI API Connectivity Test ===")
    Logger.info("API URL: #{api_url}")
    Logger.info("API Key: #{String.slice(api_key, 0, 15)}...")
    Logger.info("API Version: v2")

    # Test basic endpoint
    test_urls = [
      "#{api_url}/v2/upload",
      "#{api_url}/v2/openapi/task",
      "#{api_url}/health"
    ]

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"User-Agent", "RealProductSizeBackend/1.0"},
      {"Accept", "application/json"}
    ]

    Enum.each(test_urls, fn url ->
      Logger.info("Testing URL: #{url}")

      case Finch.build(:get, url, headers)
           |> Finch.request(@finch_name, receive_timeout: 10_000) do
        {:ok, %{status: status, body: body, headers: response_headers}} ->
          Logger.info("✅ #{url} -> HTTP #{status}")
          Logger.debug("Response headers: #{inspect(response_headers)}")

          if status in [200, 404, 401, 403] do
            Logger.debug("Response body: #{String.slice(body, 0, 200)}...")
          end

          if status == 307 do
            location = Enum.find_value(response_headers, fn {k, v} ->
              if String.downcase(k) == "location", do: v
            end)
            Logger.warning("⚠️ Redirect detected to: #{location}")
          end

        {:ok, %{status: status, headers: headers}} ->
          Logger.warning("⚠️ #{url} -> HTTP #{status}")
          Logger.debug("Response headers: #{inspect(headers)}")

        {:error, reason} ->
          Logger.error("❌ #{url} -> Error: #{inspect(reason)}")
      end
    end)

    Logger.info("=== End Connectivity Test ===")
    :ok
  end

  @doc """
  List all available images from the manual uploads directory
  """
  def list_manual_images do
    case File.ls(@manual_images_path) do
      {:ok, files} ->
        images =
          files
          |> Enum.filter(&String.ends_with?(&1, [".jpg", ".jpeg", ".png"]))
          |> Enum.map(fn filename ->
            %{
              filename: filename,
              path: Path.join(@manual_images_path, filename),
              url: "/product_imgs/manual/#{filename}"
            }
          end)
          |> Enum.sort_by(& &1.filename)

        Logger.info("Found #{length(images)} manual images")
        {:ok, images}

      {:error, reason} ->
        Logger.error("Failed to list manual images: #{inspect(reason)}")
        {:error, "Could not access manual images directory"}
    end
  end

  @doc """
  List all uploaded GLB files from the test models directory
  """
  def list_uploaded_glb_files do
    case File.ls(@test_models_path) do
      {:ok, files} ->
        glb_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".glb"))
          |> Enum.map(fn filename ->
            file_path = Path.join(@test_models_path, filename)

            case File.stat(file_path) do
              {:ok, stat} ->
                %{
                  filename: filename,
                  path: file_path,
                  url: "/3d/test/#{filename}",
                  size: stat.size,
                  modified: stat.mtime
                }
              {:error, _reason} ->
                %{
                  filename: filename,
                  path: file_path,
                  url: "/3d/test/#{filename}",
                  size: 0,
                  modified: {{1970, 1, 1}, {0, 0, 0}}
                }
            end
          end)
          |> Enum.sort_by(& &1.filename, :desc)

        Logger.info("Found #{length(glb_files)} GLB files")
        {:ok, glb_files}

      {:error, :enoent} ->
        # Directory doesn't exist, create it and return empty list
        File.mkdir_p!(@test_models_path)
        {:ok, []}

      {:error, reason} ->
        Logger.error("Failed to list GLB files: #{inspect(reason)}")
        {:error, "Could not access GLB files directory"}
    end
  end

  @doc """
  Save an uploaded GLB file to the test models directory
  """
  def save_uploaded_glb(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        # Validate file size (50MB limit)
        if byte_size(data) > 50_000_000 do
          {:error, "File size exceeds 50MB limit"}
        else
          # Generate unique filename
          original_filename = Path.basename(file_path)
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          new_filename = "uploaded_#{timestamp}_#{original_filename}"

          # Ensure only .glb extension
          final_filename =
            if String.ends_with?(new_filename, ".glb") do
              new_filename
            else
              "#{new_filename}.glb"
            end

          save_path = Path.join(@test_models_path, final_filename)

          case File.write(save_path, data) do
            :ok ->
              Logger.info("GLB file saved to: #{save_path}")
              {:ok, %{filename: final_filename, url: "/3d/test/#{final_filename}", size: byte_size(data)}}

            {:error, reason} ->
              Logger.error("Failed to save GLB file: #{inspect(reason)}")
              {:error, "Failed to save file"}
          end
        end

      {:error, reason} ->
        Logger.error("Failed to read GLB file: #{inspect(reason)}")
        {:error, "Failed to read file"}
    end
  end

  @doc """
  Delete an uploaded GLB file
  """
  def delete_glb_file(filename) do
    # Security: only allow deleting files in the test_models_path
    full_path = Path.join(@test_models_path, filename)

    # Double check the resolved path is still within the test_models_path
    if String.starts_with?(Path.expand(full_path), Path.expand(@test_models_path)) do
      case File.exists?(full_path) do
        true ->
          case File.rm(full_path) do
            :ok ->
              Logger.info("Deleted GLB file: #{full_path}")
              :ok

            {:error, reason} ->
              Logger.error("Failed to delete GLB file: #{inspect(reason)}")
              {:error, "Failed to delete file"}
          end

        false ->
          {:error, "File not found"}
      end
    else
      {:error, "Invalid file path"}
    end
  end

  @doc """
  Submit selected images to TripoAI API for 3D model generation
  """
  def test_generate_model(image_paths) when is_list(image_paths) do
    Logger.info("Starting TripoAI test generation with #{length(image_paths)} images")

    # Ensure test models directory exists
    File.mkdir_p!(@test_models_path)

    CircuitBreaker.call_with_circuit_breaker(
      :tripo_api,
      fn -> do_tripo_submission(image_paths) end,
      fn ->
        Logger.error("TripoAI API circuit breaker opened")
        {:error, :service_unavailable}
      end
    )
  end

  defp do_tripo_submission(image_paths) do
    Logger.info("Starting TripoAI submission with #{length(image_paths)} images")

    # Only use first image for single-image test
    image_path = List.first(image_paths)
    Logger.info("Using image: #{Path.basename(image_path)}")

    case upload_image_to_tripo(image_path) do
      {:ok, image_token} ->
        Logger.info("Image uploaded successfully, creating task...")

        # Create image-to-model task
        request_body = Jason.encode!(%{
          "type" => "image_to_model",
          "file" => %{
            "type" => "png",
            "file_token" => image_token
          }
        })

        headers = [
          {"Authorization", "Bearer #{get_tripo_config()[:api_key]}"},
          {"Content-Type", "application/json"}
        ]

        url = "#{get_tripo_config()[:api_url]}/v2/openapi/task"

        Logger.info("Creating image-to-model task at: #{url}")
        Logger.debug("Request body: #{request_body}")

        case Finch.build(:post, url, headers, request_body)
             |> Finch.request(@finch_name, receive_timeout: get_tripo_config()[:timeout]) do
          {:ok, %{status: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"data" => %{"task_id" => task_id}}} ->
                Logger.info("Task created successfully: #{task_id}")
                {:ok, %{task_id: task_id}}
              {:ok, response} ->
                Logger.error("Invalid task response: #{inspect(response)}")
                {:error, "Invalid task response: #{inspect(response)}"}
            end

          {:ok, %{status: status, body: body}} ->
            Logger.error("Task creation failed: HTTP #{status}, body: #{body}")
            {:error, "HTTP #{status}: #{body}"}

          {:error, reason} ->
            Logger.error("Task creation request failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Image upload failed: #{reason}")
        {:error, "Image upload failed: #{reason}"}
    end
  end

  @doc """
  Check the status of a TripoAI task
  """
  def check_task_status(task_id) do
    Logger.debug("Checking TripoAI task status: #{task_id}")

    headers = [
      {"Authorization", "Bearer #{get_tripo_config()[:api_key]}"}
    ]

    url = "#{get_tripo_config()[:api_url]}/v2/openapi/task/#{task_id}"

    case Finch.build(:get, url, headers)
         |> Finch.request(@finch_name, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"data" => data}} ->
            status = Map.get(data, "status")
            Logger.debug("TripoAI task #{task_id} status: #{status}")
            {:ok, %{status: status, response: data}}

          {:ok, response} ->
            Logger.warning("Invalid status response from TripoAI: #{inspect(response)}")
            {:error, "Invalid status response format"}

          {:error, decode_error} ->
            Logger.warning("JSON decode error from TripoAI status: #{inspect(decode_error)}")
            {:error, "JSON decode error"}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("TripoAI status check error: HTTP #{status}, body: #{body}")
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        Logger.error("TripoAI status check failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Download and save the generated 3D model
  """
  def download_and_save_model(model_url, filename) do
    Logger.info("Downloading 3D model from: #{model_url}")

    case Finch.build(:get, model_url)
         |> Finch.request(@finch_name, receive_timeout: 300_000) do
      {:ok, %{status: 200, body: body}} ->
        file_path = Path.join(@test_models_path, "#{filename}.glb")

        case File.write(file_path, body) do
          :ok ->
            Logger.info("3D model saved to: #{file_path}")
            {:ok, %{file_path: file_path, url: "/3d/test/#{filename}.glb", size: byte_size(body)}}

          {:error, reason} ->
            Logger.error("Failed to save 3D model: #{inspect(reason)}")
            {:error, "Failed to save model file"}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Model download failed: HTTP #{status}, body: #{body}")
        {:error, "Download failed: HTTP #{status}"}

      {:error, reason} ->
        Logger.error("Model download failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions


  defp upload_image_to_tripo(image_path) do
    case File.read(image_path) do
      {:ok, image_data} ->
        filename = Path.basename(image_path)
        file_type = case Path.extname(filename) do
          ".png" -> "png"
          _ -> "jpg"
        end

        # Create multipart for upload
        boundary = "----FormBoundary#{:rand.uniform(1_000_000)}"
        body = build_upload_multipart(image_data, filename, file_type, boundary)

        headers = [
          {"Authorization", "Bearer #{get_tripo_config()[:api_key]}"},
          {"Content-Type", "multipart/form-data; boundary=#{boundary}"}
        ]

        url = "#{get_tripo_config()[:api_url]}/v2/upload"

        Logger.info("Uploading image to TripoAI: #{url}")
        Logger.debug("Image: #{filename}, Type: #{file_type}")

        case Finch.build(:post, url, headers, body)
             |> Finch.request(@finch_name, receive_timeout: 30_000) do
          {:ok, %{status: 200, body: response_body}} ->
            case Jason.decode(response_body) do
              {:ok, %{"data" => %{"image_token" => image_token}}} ->
                Logger.info("Image uploaded successfully, token: #{String.slice(image_token, 0, 10)}...")
                {:ok, image_token}
              {:ok, response} ->
                Logger.error("Invalid upload response: #{inspect(response)}")
                {:error, "Invalid upload response"}
            end
          {:ok, %{status: status, body: body}} ->
            Logger.error("Upload failed: HTTP #{status} - #{body}")
            {:error, "Upload failed: HTTP #{status} - #{body}"}
          {:error, reason} ->
            Logger.error("Upload request failed: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, reason} ->
        Logger.error("Failed to read image: #{reason}")
        {:error, "Failed to read image: #{reason}"}
    end
  end

  defp build_upload_multipart(image_data, filename, file_type, boundary) do
    [
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n",
      "Content-Type: image/#{file_type}\r\n",
      "\r\n",
      image_data,
      "\r\n",
      "--#{boundary}\r\n",
      "Content-Disposition: form-data; name=\"type\"\r\n",
      "\r\n",
      file_type,
      "\r\n",
      "--#{boundary}--\r\n"
    ]
    |> Enum.join()
  end
end
