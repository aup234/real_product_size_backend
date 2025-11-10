defmodule RealProductSizeBackend.Jobs.Generate3DModelJob do
  @moduledoc """
  Background job for generating 3D models using TriPo API
  """

  use Oban.Worker, queue: :tripo, max_attempts: 3

  require Logger
  alias RealProductSizeBackend.TriPoService

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => product_id}}) do
    Logger.info("Starting background 3D model generation for product #{product_id}")

    case TriPoService.generate_3d_model(product_id) do
      {:ok, _model_data} ->
        Logger.info("Successfully completed 3D model generation for product #{product_id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to generate 3D model for product #{product_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 1min, 4min, 9min, 16min, 25min
    attempt * attempt * 60
  end
end
