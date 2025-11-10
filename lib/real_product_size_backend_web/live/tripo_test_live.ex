defmodule RealProductSizeBackendWeb.TripoTestLive do
  use RealProductSizeBackendWeb, :live_view

  alias RealProductSizeBackend.{TripoTestService, TriPoService, Products, TripoGenerationLogs}
  alias RealProductSizeBackend.Products.Product

  @impl true
  def mount(_params, _session, socket) do
    # Load images and GLB files
    images_result = TripoTestService.list_manual_images()
    glb_files_result = TripoTestService.list_uploaded_glb_files()

    images = case images_result do
      {:ok, imgs} -> imgs
      {:error, _} -> []
    end

    glb_files = case glb_files_result do
      {:ok, files} -> files
      {:error, _} -> []
    end

    # Get or create a test product
    test_product = get_or_create_test_product()

    # Subscribe to product updates
    if test_product do
      Phoenix.PubSub.subscribe(RealProductSizeBackend.PubSub, "product_updates:#{test_product.id}")
    end

    socket =
      socket
      |> assign(:images, images)
      |> assign(:selected_image, nil)
      |> assign(:generation_status, :idle)
      |> assign(:test_product, test_product)
      |> assign(:task_id, nil)
      |> assign(:model_url, nil)
      |> assign(:model_filename, nil)
      |> assign(:error_message, nil)
      |> assign(:progress, 0)
      |> assign(:debug_logs, [])
      |> assign(:uploaded_glb_files, glb_files)
      |> assign(:selected_glb, nil)
      |> assign(:generation_log, nil)
      |> assign(:manual_task_id, "")
      |> assign(:task_checking_status, nil)
      |> assign(:task_status_data, nil)
      |> allow_upload(:glb_file,
        accept: [".glb"],
        max_entries: 1,
        max_file_size: 50_000_000
      )

    # Check if there's an active generation
    socket = if test_product do
      case TripoGenerationLogs.get_active_generation(test_product.id) do
        nil -> socket
        log ->
          socket
          |> assign(:generation_status, :generating)
          |> assign(:task_id, log.task_id)
          |> assign(:progress, log.progress || 0)
          |> assign(:generation_log, log)
          |> add_debug_log("Found active generation: #{log.task_id}")
      end
    else
      socket
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_image", %{"filename" => filename}, socket) do
    # Find the full image info
    image = Enum.find(socket.assigns.images, &(&1.filename == filename))

    socket =
      socket
      |> assign(:selected_image, image)
      |> add_debug_log("Selected image: #{filename}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_model", _params, socket) do
    selected_image = socket.assigns.selected_image
    test_product = socket.assigns.test_product

    cond do
      is_nil(selected_image) ->
        socket =
          socket
          |> assign(:error_message, "Please select an image")
          |> add_debug_log("No image selected")
        {:noreply, socket}

      is_nil(test_product) ->
        socket =
          socket
          |> assign(:error_message, "Test product not available")
          |> add_debug_log("Test product not available")
        {:noreply, socket}

      true ->
        # Update test product with the selected image URL
        socket = add_debug_log(socket, "Updating test product with image URL: #{selected_image.url}")

        case Products.update_product(test_product, %{
          primary_image_url: selected_image.url,
          image_urls: [selected_image.url]
        }) do
          {:ok, updated_product} ->
            socket = add_debug_log(socket, "Product updated successfully")

            # Trigger 3D model generation using the actual service
            socket = add_debug_log(socket, "Triggering 3D model generation...")

            case TriPoService.generate_3d_model(updated_product.id) do
              {:ok, %{job_id: job_id, status: "queued"}} ->
                socket =
                  socket
                  |> assign(:generation_status, :generating)
                  |> assign(:error_message, nil)
                  |> assign(:progress, 0)
                  |> assign(:test_product, updated_product)
                  |> add_debug_log("Generation queued with job_id: #{job_id}")
                  |> add_debug_log("Waiting for task submission...")

                # Start polling for updates
                schedule_status_check(500)

                {:noreply, socket}

              {:error, reason} ->
                socket =
                  socket
                  |> assign(:generation_status, :failed)
                  |> assign(:error_message, "Failed to queue generation: #{inspect(reason)}")
                  |> add_debug_log("Generation failed: #{inspect(reason)}")

                {:noreply, socket}
            end

          {:error, reason} ->
            socket =
              socket
              |> assign(:error_message, "Failed to update product: #{inspect(reason)}")
              |> add_debug_log("Product update failed: #{inspect(reason)}")

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_glb", _params, socket) do
    socket = add_debug_log(socket, "Starting GLB file upload...")

    case consume_uploaded_entries(socket, :glb_file, fn %{path: path}, _entry ->
      TripoTestService.save_uploaded_glb(path)
    end) do
      [result] ->
        case result do
          {:ok, file_info} ->
            socket = add_debug_log(socket, "GLB file uploaded successfully: #{file_info.filename}")

            # Reload GLB files list
            {:ok, glb_files} = TripoTestService.list_uploaded_glb_files()

            socket =
              socket
              |> assign(:uploaded_glb_files, glb_files)
              |> assign(:selected_glb, file_info.filename)
              |> assign(:model_url, file_info.url)
              |> assign(:model_filename, file_info.filename)
              |> assign(:error_message, nil)

            {:noreply, socket}

          {:error, error} ->
            socket = add_debug_log(socket, "GLB upload failed: #{error}")
            socket = assign(socket, :error_message, "Upload failed: #{error}")
            {:noreply, socket}
        end

      _ ->
        socket = add_debug_log(socket, "No file was uploaded")
        socket = assign(socket, :error_message, "No file selected")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_glb", %{"filename" => filename}, socket) do
    socket = add_debug_log(socket, "Selecting GLB file: #{filename}")

    glb_file = Enum.find(socket.assigns.uploaded_glb_files, &(&1.filename == filename))

    if glb_file do
      socket =
        socket
        |> assign(:selected_glb, filename)
        |> assign(:model_url, glb_file.url)
        |> assign(:model_filename, filename)
        |> assign(:error_message, nil)

      {:noreply, socket}
    else
      socket = add_debug_log(socket, "GLB file not found: #{filename}")
      socket = assign(socket, :error_message, "File not found")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_glb", %{"filename" => filename}, socket) do
    socket = add_debug_log(socket, "Deleting GLB file: #{filename}")

    case TripoTestService.delete_glb_file(filename) do
      :ok ->
        socket = add_debug_log(socket, "GLB file deleted successfully")

        # Reload GLB files list
        {:ok, glb_files} = TripoTestService.list_uploaded_glb_files()

        socket =
          socket
          |> assign(:uploaded_glb_files, glb_files)
          |> assign(:error_message, nil)

        # If the deleted file was selected, clear the selection
        socket = if socket.assigns.selected_glb == filename do
          socket
          |> assign(:selected_glb, nil)
          |> assign(:model_url, nil)
          |> assign(:model_filename, nil)
        else
          socket
        end

        {:noreply, socket}

      {:error, error} ->
        socket = add_debug_log(socket, "Failed to delete GLB file: #{error}")
        socket = assign(socket, :error_message, "Delete failed: #{error}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_debug_logs", _params, socket) do
    socket = assign(socket, :debug_logs, [])
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_task_id", %{"task_id" => task_id}, socket) do
    socket = assign(socket, :manual_task_id, task_id || "")
    {:noreply, socket}
  end

  @impl true
  def handle_event("check_task_status", %{"task_id" => task_id}, socket) when is_binary(task_id) and task_id != "" do
    socket =
      socket
      |> assign(:manual_task_id, task_id)
      |> assign(:task_checking_status, :checking)
      |> assign(:error_message, nil)
      |> add_debug_log("Checking task status for: #{task_id}")

    # Check task status asynchronously using Task
    send(self(), {:check_task_status, task_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("check_task_status", _params, socket) do
    socket =
      socket
      |> assign(:error_message, "Please enter a task ID")
      |> add_debug_log("No task ID provided")

    {:noreply, socket}
  end

  @impl true
  def handle_event("download_task_model", %{"task_id" => task_id}, socket) do
    socket =
      socket
      |> assign(:task_checking_status, :downloading)
      |> add_debug_log("Downloading model for task: #{task_id}")

    # Download model asynchronously
    send(self(), {:download_task_model, task_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign(:selected_image, nil)
      |> assign(:generation_status, :idle)
      |> assign(:task_id, nil)
      |> assign(:model_url, nil)
      |> assign(:model_filename, nil)
      |> assign(:error_message, nil)
      |> assign(:progress, 0)
      |> assign(:selected_glb, nil)
      |> assign(:generation_log, nil)
      |> assign(:manual_task_id, "")
      |> assign(:task_checking_status, nil)
      |> assign(:task_status_data, nil)

    {:noreply, socket}
  end

  # Handle PubSub events from the generation process
  @impl true
  def handle_info({:generation_started, product_id}, socket) do
    socket = add_debug_log(socket, "Generation started for product #{product_id}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:model_ready, product_id, %{model_url: model_url}}, socket) do
    socket = add_debug_log(socket, "Model ready! URL: #{model_url}")

    # Fetch the updated product
    product = Products.get_product!(product_id)

    socket =
      socket
      |> assign(:generation_status, :completed)
      |> assign(:model_url, model_url)
      |> assign(:model_filename, Path.basename(model_url))
      |> assign(:progress, 100)
      |> assign(:test_product, product)
      |> add_debug_log("3D model generation completed successfully!")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:model_failed, _product_id, %{error: error}}, socket) do
    socket = add_debug_log(socket, "Model generation failed: #{inspect(error)}")

    socket =
      socket
      |> assign(:generation_status, :failed)
      |> assign(:error_message, "Generation failed: #{inspect(error)}")

    {:noreply, socket}
  end

  # Poll for status updates
  @impl true
  def handle_info(:check_status, socket) do
    case socket.assigns.generation_status do
      :generating ->
        test_product = socket.assigns.test_product

        if test_product do
          # Check generation log
          case TripoGenerationLogs.get_active_generation(test_product.id) do
            nil ->
              # Check if completed
              product = Products.get_product!(test_product.id)

              case product.model_generation_status do
                "completed" when not is_nil(product.ar_model_url) ->
                  socket =
                    socket
                    |> assign(:generation_status, :completed)
                    |> assign(:model_url, product.ar_model_url)
                    |> assign(:model_filename, Path.basename(product.ar_model_url))
                    |> assign(:progress, 100)
                    |> assign(:test_product, product)
                    |> add_debug_log("Generation completed! Model available at: #{product.ar_model_url}")

                  {:noreply, socket}

                "failed" ->
                  socket =
                    socket
                    |> assign(:generation_status, :failed)
                    |> assign(:error_message, "Generation failed")
                    |> add_debug_log("Generation failed")

                  {:noreply, socket}

                _ ->
                  # Still no log, keep polling
                  schedule_status_check(1000)
                  {:noreply, socket}
              end

            log ->
              # Update with log info
              socket =
                socket
                |> assign(:task_id, log.task_id)
                |> assign(:progress, log.progress || 0)
                |> assign(:generation_log, log)

              # Add debug log if status changed
              socket = if socket.assigns.generation_log != log do
                add_debug_log(socket, "Status: #{log.status}, Progress: #{log.progress}%")
              else
                socket
              end

              # Continue polling
              schedule_status_check(2000)
              {:noreply, socket}
          end
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:check_task_status, task_id}, socket) do
    case TripoTestService.check_task_status(task_id) do
      {:ok, %{status: status, response: response_data}} ->
        socket = add_debug_log(socket, "Task status: #{status}")

        # Extract PBR model URL if available
        pbr_model_url = get_in(response_data, ["result", "pbr_model", "url"])

        socket =
          socket
          |> assign(:task_checking_status, :idle)
          |> assign(:task_status_data, %{
            status: status,
            task_id: task_id,
            response: response_data,
            pbr_model_url: pbr_model_url
          })
          |> add_debug_log("Status check complete. Status: #{status}")
          |> add_debug_log(if pbr_model_url, do: "PBR model URL found", else: "No PBR model URL yet")

        # If status is success and we have a PBR model URL, automatically download it
        socket = if status == "success" and pbr_model_url do
          add_debug_log(socket, "Task completed successfully! Auto-downloading model...")
          # Trigger download
          send(self(), {:download_task_model, task_id, pbr_model_url})
          socket
        else
          socket
        end

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:task_checking_status, :idle)
          |> assign(:error_message, "Failed to check task status: #{inspect(reason)}")
          |> add_debug_log("Status check failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:download_task_model, task_id}, socket) do
    # Get PBR model URL from status data
    pbr_model_url = case socket.assigns.task_status_data do
      %{pbr_model_url: url} when is_binary(url) -> url
      _ -> nil
    end

    if pbr_model_url do
      send(self(), {:download_task_model, task_id, pbr_model_url})
    else
      socket =
        socket
        |> assign(:error_message, "No PBR model URL available. Please check task status first.")
        |> add_debug_log("Cannot download: No PBR model URL found")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:download_task_model, task_id, pbr_model_url}, socket) do
    socket = add_debug_log(socket, "Starting download from: #{pbr_model_url}")

    # Generate filename from task_id
    filename = "task_#{task_id}"

    case TripoTestService.download_and_save_model(pbr_model_url, filename) do
      {:ok, %{url: model_url, size: size}} ->
        # Extract filename from URL
        saved_filename = Path.basename(model_url)

        # Reload GLB files list
        {:ok, glb_files} = TripoTestService.list_uploaded_glb_files()

        socket =
          socket
          |> assign(:task_checking_status, :idle)
          |> assign(:model_url, model_url)
          |> assign(:model_filename, saved_filename)
          |> assign(:selected_glb, saved_filename)
          |> assign(:uploaded_glb_files, glb_files)
          |> assign(:error_message, nil)
          |> add_debug_log("Model downloaded successfully! Size: #{size} bytes")
          |> add_debug_log("Model available at: #{model_url}")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:task_checking_status, :idle)
          |> assign(:error_message, "Download failed: #{inspect(reason)}")
          |> add_debug_log("Download failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Catch-all for unknown messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp get_or_create_test_product do
    # Try to find existing test product
    case RealProductSizeBackend.Repo.get_by(Product, external_id: "tripo_test_product") do
      nil ->
        # Create a new test product
        case Products.create_product(%{
          external_id: "tripo_test_product",
          source_url: "manual",
          source_type: "manual",
          title: "TripoAI Test Product",
          description: "Test product for TripoAI 3D generation",
          crawled_at: DateTime.utc_now()
        }) do
          {:ok, product} -> product
          {:error, _} -> nil
        end

      product -> product
    end
  end

  defp schedule_status_check(delay_ms) do
    Process.send_after(self(), :check_status, delay_ms)
  end

  defp add_debug_log(socket, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()
    log_entry = %{timestamp: timestamp, message: message}

    current_logs = socket.assigns.debug_logs || []
    new_logs = [log_entry | current_logs] |> Enum.take(100)

    assign(socket, :debug_logs, new_logs)
  end

  # Helper functions for template

  defp status_text(:idle), do: "Ready to generate"
  defp status_text(:generating), do: "Generating 3D model..."
  defp status_text(:completed), do: "Generation completed!"
  defp status_text(:failed), do: "Generation failed"

  defp status_color(:idle), do: "text-gray-600"
  defp status_color(:generating), do: "text-blue-600"
  defp status_color(:completed), do: "text-green-600"
  defp status_color(:failed), do: "text-red-600"

  defp status_icon(:idle), do: "⏸️"
  defp status_icon(:generating), do: "⚙️"
  defp status_icon(:completed), do: "✅"
  defp status_icon(:failed), do: "❌"

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1_048_576 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1_073_741_824 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      true -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
    end
  end

  defp format_file_size(_), do: "0 B"

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
