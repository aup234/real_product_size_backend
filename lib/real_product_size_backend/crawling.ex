defmodule RealProductSizeBackend.Crawling do
  @moduledoc """
  The Crawling context.
  """

  import Ecto.Query, warn: false
  alias RealProductSizeBackend.Repo
  alias RealProductSizeBackend.Crawling.CrawlingHistory

  @doc """
  Creates a crawling history record.
  """
  def create_crawling_history(attrs \\ %{}) do
    %CrawlingHistory{}
    |> CrawlingHistory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates crawling history with completion data.
  """
  def complete_crawling_history(id, attrs) do
    Repo.get!(CrawlingHistory, id)
    |> CrawlingHistory.complete_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets crawling history for a user.
  """
  def list_user_crawling_history(user_id, _opts \\ []) do
    CrawlingHistory
    |> where([ch], ch.user_id == ^user_id)
    |> order_by([ch], desc: ch.started_at)
    |> Repo.all()
  end

  @doc """
  Gets crawling history for a product.
  """
  def list_product_crawling_history(product_id, _opts \\ []) do
    CrawlingHistory
    |> where([ch], ch.product_id == ^product_id)
    |> order_by([ch], desc: ch.started_at)
    |> Repo.all()
  end

  @doc """
  Gets crawling statistics for a user.
  """
  def get_user_crawling_stats(user_id, days \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    total_crawls =
      CrawlingHistory
      |> where([ch], ch.user_id == ^user_id and ch.started_at > ^cutoff_date)
      |> Repo.aggregate(:count, :id)

    successful_crawls =
      CrawlingHistory
      |> where(
        [ch],
        ch.user_id == ^user_id and ch.started_at > ^cutoff_date and ch.status == "success"
      )
      |> Repo.aggregate(:count, :id)

    failed_crawls =
      CrawlingHistory
      |> where(
        [ch],
        ch.user_id == ^user_id and ch.started_at > ^cutoff_date and ch.status == "failed"
      )
      |> Repo.aggregate(:count, :id)

    blocked_crawls =
      CrawlingHistory
      |> where(
        [ch],
        ch.user_id == ^user_id and ch.started_at > ^cutoff_date and ch.was_blocked == true
      )
      |> Repo.aggregate(:count, :id)

    %{
      total_crawls: total_crawls,
      successful_crawls: successful_crawls,
      failed_crawls: failed_crawls,
      blocked_crawls: blocked_crawls,
      # TODO: Implement average calculation
      avg_processing_time: 0
    }
  end

  @doc """
  Gets global crawling statistics.
  """
  def get_global_crawling_stats(days \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    total_crawls =
      CrawlingHistory
      |> where([ch], ch.started_at > ^cutoff_date)
      |> Repo.aggregate(:count, :id)

    successful_crawls =
      CrawlingHistory
      |> where([ch], ch.started_at > ^cutoff_date and ch.status == "success")
      |> Repo.aggregate(:count, :id)

    failed_crawls =
      CrawlingHistory
      |> where([ch], ch.started_at > ^cutoff_date and ch.status == "failed")
      |> Repo.aggregate(:count, :id)

    blocked_crawls =
      CrawlingHistory
      |> where([ch], ch.started_at > ^cutoff_date and ch.was_blocked == true)
      |> Repo.aggregate(:count, :id)

    %{
      total_crawls: total_crawls,
      successful_crawls: successful_crawls,
      failed_crawls: failed_crawls,
      blocked_crawls: blocked_crawls,
      # TODO: Implement average calculation
      avg_processing_time: 0,
      # TODO: Implement distinct user count
      total_users: 0
    }
  end

  @doc """
  Gets crawling statistics by source type.
  """
  def get_crawling_stats_by_source_type(days \\ 30) do
    _cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # For now, return basic stats
    %{
      amazon: %{total_crawls: 0, successful_crawls: 0, failed_crawls: 0, blocked_crawls: 0},
      ebay: %{total_crawls: 0, successful_crawls: 0, failed_crawls: 0, blocked_crawls: 0},
      walmart: %{total_crawls: 0, successful_crawls: 0, failed_crawls: 0, blocked_crawls: 0}
    }
  end

  @doc """
  Gets blocked crawling attempts.
  """
  def get_blocked_crawling_attempts(_opts \\ []) do
    CrawlingHistory
    |> where([ch], ch.was_blocked == true)
    |> order_by([ch], desc: ch.started_at)
    |> Repo.all()
  end

  @doc """
  Gets crawling errors for debugging.
  """
  def get_crawling_errors(_opts \\ []) do
    CrawlingHistory
    |> where([ch], ch.status == "failed")
    |> order_by([ch], ch.started_at)
    |> Repo.all()
  end

  @doc """
  Retries a failed crawling attempt.
  """
  def retry_crawling_attempt(id) do
    case Repo.get(CrawlingHistory, id) do
      nil ->
        {:error, :not_found}

      history ->
        # Increment retry count
        history
        |> Ecto.Changeset.change(%{retry_count: history.retry_count + 1})
        |> Repo.update()
    end
  end
end
