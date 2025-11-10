defmodule RealProductSizeBackend.TripoGenerationLogs do
  @moduledoc """
  Context for managing TripoAI 3D model generation logs.
  """

  import Ecto.Query, warn: false
  alias RealProductSizeBackend.Repo
  alias RealProductSizeBackend.TripoGenerationLogs.TripoGenerationLog

  @doc """
  Creates a new generation log entry.
  """
  def create_log(product_id, task_id, request_payload) do
    %TripoGenerationLog{}
    |> TripoGenerationLog.changeset(%{
      product_id: product_id,
      task_id: task_id,
      status: "queued",
      progress: 0,
      request_payload: request_payload
    })
    |> Repo.insert()
  end

  @doc """
  Updates a log entry's status and response data.
  """
  def update_log_status(task_id, status, response_data) do
    case get_log_by_task_id(task_id) do
      nil ->
        {:error, :log_not_found}

      log ->
        progress = get_in(response_data, ["progress"]) || log.progress

        log
        |> TripoGenerationLog.changeset(%{
          status: status,
          progress: progress,
          response_data: response_data,
          pbr_model_url: get_in(response_data, ["result", "pbr_model", "url"]),
          rendered_image_url: get_in(response_data, ["result", "rendered_image", "url"]),
          generated_image_url: get_in(response_data, ["output", "generated_image"]),
          error_message: get_in(response_data, ["error"])
        })
        |> Repo.update()
    end
  end

  @doc """
  Updates a log entry with the local file path after download.
  """
  def update_log_with_local_path(task_id, local_path) do
    case get_log_by_task_id(task_id) do
      nil ->
        {:error, :log_not_found}

      log ->
        log
        |> TripoGenerationLog.changeset(%{local_model_path: local_path})
        |> Repo.update()
    end
  end

  @doc """
  Gets a log entry by task ID.
  """
  def get_log_by_task_id(task_id) do
    Repo.get_by(TripoGenerationLog, task_id: task_id)
  end

  @doc """
  Gets all log entries for a product.
  """
  def get_logs_by_product_id(product_id) do
    TripoGenerationLog
    |> where([l], l.product_id == ^product_id)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets the active (in-progress) generation for a product.
  """
  def get_active_generation(product_id) do
    TripoGenerationLog
    |> where([l], l.product_id == ^product_id)
    |> where([l], l.status in ["queued", "processing"])
    |> order_by([l], desc: l.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
