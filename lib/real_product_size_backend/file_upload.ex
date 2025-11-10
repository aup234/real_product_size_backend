defmodule RealProductSizeBackend.FileUpload do
  @moduledoc """
  Handles file uploads for manual product entry.
  Provides validation, storage, and URL generation for uploaded images.
  """

  require Logger
  alias RealProductSizeBackendWeb.Endpoint

  @max_file_size 10 * 1024 * 1024 # 10MB
  @allowed_content_types ["image/jpeg", "image/jpg", "image/png"]
  @upload_dir "priv/static/product_imgs/manual"

  @doc """
  Validates an uploaded file for image requirements.
  """
  def validate_image(%Plug.Upload{} = upload) do
    with :ok <- validate_file_size(upload),
         :ok <- validate_content_type(upload) do
      {:ok, upload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_image(_), do: {:error, "Invalid file upload"}

  @doc """
  Saves an uploaded image to the filesystem and returns the filename.
  """
  def save_uploaded_image(%Plug.Upload{} = upload, prefix \\ "") do
    with {:ok, upload} <- validate_image(upload),
         {:ok, filename} <- generate_filename(upload, prefix),
         {:ok, _} <- ensure_upload_directory(),
         {:ok, _} <- copy_file(upload, filename) do
      {:ok, filename}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a public URL for a saved image file.
  """
  def generate_image_url(filename, host \\ nil) do
    base_url = if host, do: host, else: Endpoint.url()
    url = "#{base_url}/product_imgs/manual/#{filename}"
    Logger.debug("FileUpload: Generated image URL for #{filename}: #{url} (using base: #{base_url})")
    url
  end

  @doc """
  Saves multiple images and returns a list of URLs.
  """
  def save_multiple_images(uploads, host \\ nil) when is_list(uploads) do
    Logger.info("FileUpload: Saving #{length(uploads)} images")

    uploads
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {upload, index}, {:ok, acc} ->
      Logger.debug("FileUpload: Processing image #{index + 1}/#{length(uploads)}")
      Logger.debug("FileUpload: Upload details - filename: #{upload.filename}, content_type: #{upload.content_type}")

      case save_uploaded_image(upload, "img_#{index}") do
        {:ok, filename} ->
          url = generate_image_url(filename, host)
          Logger.debug("FileUpload: Successfully saved image #{index + 1} as #{filename} -> #{url}")
          {:cont, {:ok, [url | acc]}}
        {:error, reason} ->
          Logger.error("FileUpload: Failed to save image #{index + 1}: #{reason}")
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, urls} ->
        Logger.info("FileUpload: Successfully generated #{length(urls)} image URLs")
        {:ok, Enum.reverse(urls)}
      {:error, reason} ->
        Logger.error("FileUpload: Failed to save images: #{reason}")
        {:error, reason}
    end
  end

  # Private functions

  defp validate_file_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_file_size ->
        :ok
      {:ok, %{size: size}} ->
        {:error, "File too large: #{size} bytes (max #{@max_file_size})"}
      {:error, reason} ->
        {:error, "Could not read file: #{reason}"}
    end
  end

  defp validate_content_type(%Plug.Upload{content_type: content_type}) do
    if content_type in @allowed_content_types do
      :ok
    else
      {:error, "Invalid content type: #{content_type}. Allowed: #{Enum.join(@allowed_content_types, ", ")}"}
    end
  end

  defp generate_filename(%Plug.Upload{filename: original_filename}, prefix) do
    extension = Path.extname(original_filename)
    uuid = Ecto.UUID.generate()
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    filename = if prefix != "" do
      "#{prefix}_#{uuid}_#{timestamp}#{extension}"
    else
      "#{uuid}_#{timestamp}#{extension}"
    end

    {:ok, filename}
  end

  defp ensure_upload_directory do
    case File.mkdir_p(@upload_dir) do
      :ok -> {:ok, @upload_dir}
      {:error, reason} -> {:error, "Could not create upload directory: #{reason}"}
    end
  end

  defp copy_file(%Plug.Upload{path: source_path}, filename) do
    destination = Path.join(@upload_dir, filename)

    case File.cp(source_path, destination) do
      :ok -> {:ok, destination}
      {:error, reason} -> {:error, "Could not save file: #{reason}"}
    end
  end
end
