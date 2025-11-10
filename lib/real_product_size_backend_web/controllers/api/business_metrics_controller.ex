defmodule RealProductSizeBackendWeb.Api.BusinessMetricsController do
  use RealProductSizeBackendWeb, :controller

  alias RealProductSizeBackend.{
    UsageAnalytics,
    Subscriptions,
    Products,
    Accounts
  }

  require Logger

  @doc """
  Get comprehensive business metrics dashboard
  """
  def dashboard(conn, _params) do
    with {:ok, metrics} <- get_business_metrics() do
      render(conn, :dashboard, metrics: metrics)
    else
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch metrics: #{reason}"})
    end
  end

  @doc """
  Get user acquisition metrics
  """
  def user_acquisition(conn, params) do
    %{"start_date" => start_date, "end_date" => end_date} = params

    with {:ok, start_dt} <- Date.from_iso8601(start_date),
         {:ok, end_dt} <- Date.from_iso8601(end_date),
         {:ok, metrics} <- get_user_acquisition_metrics(start_dt, end_dt) do
      render(conn, :user_acquisition, metrics: metrics)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid date format. Use YYYY-MM-DD"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch user acquisition metrics: #{reason}"})
    end
  end

  @doc """
  Get revenue analytics
  """
  def revenue_analytics(conn, params) do
    %{"start_date" => start_date, "end_date" => end_date} = params

    with {:ok, start_dt} <- Date.from_iso8601(start_date),
         {:ok, end_dt} <- Date.from_iso8601(end_date),
         {:ok, metrics} <- get_revenue_metrics(start_dt, end_dt) do
      render(conn, :revenue_analytics, metrics: metrics)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid date format. Use YYYY-MM-DD"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch revenue metrics: #{reason}"})
    end
  end

  @doc """
  Get user engagement metrics
  """
  def user_engagement(conn, params) do
    %{"start_date" => start_date, "end_date" => end_date} = params

    with {:ok, start_dt} <- Date.from_iso8601(start_date),
         {:ok, end_dt} <- Date.from_iso8601(end_date),
         {:ok, metrics} <- get_engagement_metrics(start_dt, end_dt) do
      render(conn, :user_engagement, metrics: metrics)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid date format. Use YYYY-MM-DD"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch engagement metrics: #{reason}"})
    end
  end

  @doc """
  Get subscription analytics
  """
  def subscription_analytics(conn, params) do
    %{"start_date" => start_date, "end_date" => end_date} = params

    with {:ok, start_dt} <- Date.from_iso8601(start_date),
         {:ok, end_dt} <- Date.from_iso8601(end_date),
         {:ok, metrics} <- get_subscription_metrics(start_dt, end_dt) do
      render(conn, :subscription_analytics, metrics: metrics)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid date format. Use YYYY-MM-DD"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch subscription metrics: #{reason}"})
    end
  end

  @doc """
  Get product performance metrics
  """
  def product_performance(conn, params) do
    %{"start_date" => start_date, "end_date" => end_date} = params

    with {:ok, start_dt} <- Date.from_iso8601(start_date),
         {:ok, end_dt} <- Date.from_iso8601(end_date),
         {:ok, metrics} <- get_product_performance_metrics(start_dt, end_dt) do
      render(conn, :product_performance, metrics: metrics)
    else
      {:error, :invalid_date} ->
        conn
        |> put_status(400)
        |> json(%{error: "Invalid date format. Use YYYY-MM-DD"})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch product performance metrics: #{reason}"})
    end
  end

  @doc """
  Get real-time metrics
  """
  def realtime_metrics(conn, _params) do
    with {:ok, metrics} <- get_realtime_metrics() do
      render(conn, :realtime_metrics, metrics: metrics)
    else
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to fetch real-time metrics: #{reason}"})
    end
  end

  # Private functions for metrics calculation

  defp get_business_metrics do
    try do
      # Get basic metrics
      total_users = Accounts.count_users()
      active_users_today = UsageAnalytics.count_daily_active_users()
      total_sessions = UsageAnalytics.count_total_sessions()
      ar_sessions = UsageAnalytics.count_ar_sessions()
      models_generated = Products.count_generated_models()

      # Get subscription metrics
      total_subscriptions = Subscriptions.count_active_subscriptions()
      premium_subscriptions = Subscriptions.count_subscriptions_by_tier("premium")
      pro_subscriptions = Subscriptions.count_subscriptions_by_tier("pro")

      # Calculate conversion rates
      conversion_rate = if total_users > 0, do: (total_subscriptions / total_users) * 100, else: 0

      # Get revenue metrics
      monthly_recurring_revenue = Subscriptions.calculate_mrr()

      metrics = %{
        users: %{
          total: total_users,
          active_today: active_users_today,
          new_today: UsageAnalytics.count_new_users_today()
        },
        sessions: %{
          total: total_sessions,
          ar_sessions: ar_sessions,
          avg_session_duration: UsageAnalytics.avg_session_duration()
        },
        products: %{
          models_generated: models_generated,
          successful_generations: Products.count_successful_generations(),
          failed_generations: Products.count_failed_generations()
        },
        subscriptions: %{
          total: total_subscriptions,
          premium: premium_subscriptions,
          pro: pro_subscriptions,
          conversion_rate: conversion_rate
        },
        revenue: %{
          mrr: monthly_recurring_revenue,
          total_revenue: Subscriptions.calculate_total_revenue()
        }
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get business metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_user_acquisition_metrics(start_date, end_date) do
    try do
      new_users = Accounts.count_users_by_date_range(start_date, end_date)
      user_sources = UsageAnalytics.get_user_sources(start_date, end_date)

      metrics = %{
        new_users: new_users,
        user_sources: user_sources,
        acquisition_cost: calculate_acquisition_cost(start_date, end_date)
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get user acquisition metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_revenue_metrics(start_date, end_date) do
    try do
      revenue = Subscriptions.calculate_revenue_by_date_range(start_date, end_date)
      subscription_revenue = Subscriptions.calculate_subscription_revenue(start_date, end_date)
      churn_revenue = Subscriptions.calculate_churn_revenue(start_date, end_date)

      metrics = %{
        total_revenue: revenue,
        subscription_revenue: subscription_revenue,
        churn_revenue: churn_revenue,
        revenue_growth: calculate_revenue_growth(start_date, end_date)
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get revenue metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_engagement_metrics(start_date, end_date) do
    try do
      daily_active_users = UsageAnalytics.count_daily_active_users_by_date_range(start_date, end_date)
      session_duration = UsageAnalytics.avg_session_duration_by_date_range(start_date, end_date)
      retention_rates = UsageAnalytics.calculate_retention_rates(start_date, end_date)

      metrics = %{
        daily_active_users: daily_active_users,
        avg_session_duration: session_duration,
        retention_rates: retention_rates,
        engagement_score: calculate_engagement_score(start_date, end_date)
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get engagement metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_subscription_metrics(start_date, end_date) do
    try do
      new_subscriptions = Subscriptions.count_new_subscriptions(start_date, end_date)
      cancellations = Subscriptions.count_cancellations(start_date, end_date)
      churn_rate = Subscriptions.calculate_churn_rate(start_date, end_date)
      ltv = Subscriptions.calculate_ltv()

      metrics = %{
        new_subscriptions: new_subscriptions,
        cancellations: cancellations,
        churn_rate: churn_rate,
        lifetime_value: ltv,
        subscription_growth: calculate_subscription_growth(start_date, end_date)
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get subscription metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_product_performance_metrics(start_date, end_date) do
    try do
      top_products = Products.get_top_products_by_usage(start_date, end_date)
      generation_success_rate = Products.calculate_generation_success_rate(start_date, end_date)
      avg_generation_time = Products.calculate_avg_generation_time(start_date, end_date)

      metrics = %{
        top_products: top_products,
        generation_success_rate: generation_success_rate,
        avg_generation_time: avg_generation_time,
        platform_breakdown: Products.get_platform_breakdown(start_date, end_date)
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get product performance metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  defp get_realtime_metrics do
    try do
      active_users_now = UsageAnalytics.count_active_users_now()
      current_sessions = UsageAnalytics.count_current_sessions()
      models_generating = Products.count_models_generating()

      metrics = %{
        active_users_now: active_users_now,
        current_sessions: current_sessions,
        models_generating: models_generating,
        system_health: get_system_health()
      }

      {:ok, metrics}
    rescue
      error ->
        Logger.error("Failed to get real-time metrics: #{inspect(error)}")
        {:error, "Database error"}
    end
  end

  # Helper functions for calculations
  defp calculate_acquisition_cost(_start_date, _end_date) do
    # This would calculate cost per acquisition based on marketing spend
    0.0
  end

  defp calculate_revenue_growth(_start_date, _end_date) do
    # This would calculate revenue growth percentage
    0.0
  end

  defp calculate_engagement_score(_start_date, _end_date) do
    # This would calculate a composite engagement score
    0.0
  end

  defp calculate_subscription_growth(_start_date, _end_date) do
    # This would calculate subscription growth percentage
    0.0
  end

  defp get_system_health do
    # This would return system health metrics
    %{
      database_status: "healthy",
      api_response_time: "50ms",
      error_rate: "0.1%"
    }
  end
end
