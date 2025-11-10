defmodule RealProductSizeBackend.TripoGenerationWorker do
  @moduledoc """
  Oban worker for processing 3D model generation jobs.
  Submits tasks to TripoAI and queues status polling.
  """

  use Oban.Worker, queue: :tripo_generation, max_attempts: 3

  require Logger
  alias RealProductSizeBackend.TriPoService

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => product_id}}) do
    Logger.info("Starting 3D model generation worker for product #{product_id}")

    case TriPoService.process_3d_model_generation(product_id) do
      {:ok, %{task_id: task_id}} ->
        Logger.info("Successfully submitted task #{task_id} for product #{product_id}")
        {:ok, %{task_id: task_id}}

      {:error, :disabled_in_production} ->
        Logger.info("3D model generation disabled in production for product #{product_id}")
        :discard

      {:error, :skipped_for_debug} ->
        Logger.info("3D model generation skipped in debug mode for product #{product_id}")
        :discard

      {:error, :service_disabled} ->
        Logger.info("TriPo service disabled for product #{product_id}")
        :discard

      {:error, reason} ->
        Logger.error("3D model generation failed for product #{product_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 1min, 4min, 9min
    attempt * attempt * 60
  end
end
