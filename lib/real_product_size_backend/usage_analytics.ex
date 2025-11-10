defmodule RealProductSizeBackend.UsageAnalytics do
  @moduledoc """
  Usage analytics and tracking for subscription limits and business intelligence.

  This module provides detailed tracking of user actions, platform usage,
  and performance metrics for business analysis.
  """

  require Logger
  alias RealProductSizeBackend.Subscriptions
  alias RealProductSizeBackend.Repo
  import Ecto.Query

  @doc """
  Tracks a user action with detailed analytics.

  Returns {:ok, analytics_data} or {:error, reason}
  """
  def track_action(user_id, action, metadata \\ %{}) do
    with {:ok, _usage} <- Subscriptions.track_usage(user_id, action) do
      # Create detailed analytics record
      analytics_data = %{
        user_id: user_id,
        action: action,
        timestamp: DateTime.utc_now(),
        metadata: metadata
      }

      # Log for analytics (in production, this would go to a proper analytics service)
      Logger.info("Usage Analytics: #{inspect(analytics_data)}")

      {:ok, analytics_data}
    else
      {:error, :limit_exceeded} = error ->
        Logger.warning("Usage limit exceeded for user #{user_id}, action: #{action}")
        error
    end
  end

  @doc """
  Tracks product crawling with platform and quality metrics.
  """
  def track_product_crawl(user_id, url, platform, quality_score, success) do
    metadata = %{
      url: url,
      platform: platform,
      quality_score: quality_score,
      success: success,
      timestamp: DateTime.utc_now()
    }

    track_action(user_id, "product_crawl", metadata)
  end

  @doc """
  Tracks AR view with session details.
  """
  def track_ar_view(user_id, product_id, session_duration_ms) do
    metadata = %{
      product_id: product_id,
      session_duration_ms: session_duration_ms,
      timestamp: DateTime.utc_now()
    }

    track_action(user_id, "ar_view", metadata)
  end

  @doc """
  Tracks 3D model generation with cost and quality metrics.
  """
  def track_model_generation(user_id, product_id, generation_time_ms, cost_usd) do
    metadata = %{
      product_id: product_id,
      generation_time_ms: generation_time_ms,
      cost_usd: cost_usd,
      timestamp: DateTime.utc_now()
    }

    track_action(user_id, "model_generation", metadata)
  end

  @doc """
  Gets usage statistics for a user.
  """
  def get_user_usage_stats(user_id) do
    usage_summary = Subscriptions.get_usage_summary(user_id)
    subscription = Subscriptions.get_user_subscription(user_id)

    %{
      current_usage: usage_summary,
      subscription: subscription,
      limits: usage_summary.limits,
      utilization_percentage: calculate_utilization_percentage(usage_summary),
      days_remaining: calculate_days_remaining(usage_summary.period_end),
      upgrade_recommendations: get_upgrade_recommendations(usage_summary, subscription)
    }
  end

  @doc """
  Gets platform usage statistics.
  """
  def get_platform_usage_stats do
    # This would typically query a proper analytics database
    # For now, return mock data
    %{
      total_crawls: 1250,
      platform_breakdown: %{
        amazon: 800,
        ikea: 300,
        walmart: 100,
        target: 50
      },
      success_rates: %{
        amazon: 0.85,
        ikea: 0.92,
        walmart: 0.78,
        target: 0.80
      },
      average_quality_scores: %{
        amazon: 0.75,
        ikea: 0.88,
        walmart: 0.70,
        target: 0.72
      }
    }
  end

  @doc """
  Gets subscription tier distribution.
  """
  def get_subscription_stats do
    # This would typically query the database
    # For now, return mock data
    %{
      total_users: 1000,
      tier_distribution: %{
        free: 700,
        basic: 200,
        pro: 80,
        enterprise: 20
      },
      conversion_rates: %{
        free_to_basic: 0.15,
        basic_to_pro: 0.25,
        pro_to_enterprise: 0.10
      }
    }
  end

  @doc """
  Gets AR suitability statistics.
  """
  def get_ar_suitability_stats do
    # This would typically query the database
    %{
      total_products_analyzed: 5000,
      ar_suitable: 3500,
      ar_not_suitable: 1500,
      suitability_rate: 0.70,
      rejection_reasons: %{
        digital_product: 800,
        service: 300,
        gift_card: 200,
        no_dimensions: 200
      }
    }
  end

  # Private functions

  defp calculate_utilization_percentage(usage_summary) do
    %{limits: limits} = usage_summary

    # Calculate utilization for each metric
    ar_utilization = if limits["ar_views"] > 0, do: usage_summary.ar_views / limits["ar_views"], else: 0
    crawl_utilization = if limits["product_crawls"] > 0, do: usage_summary.product_crawls / limits["product_crawls"], else: 0
    model_utilization = if limits["model_generations"] > 0, do: usage_summary.model_generations / limits["model_generations"], else: 0
    storage_utilization = if limits["storage"] > 0, do: usage_summary.storage_used / limits["storage"], else: 0

    # Return the highest utilization percentage
    max(ar_utilization, max(crawl_utilization, max(model_utilization, storage_utilization)))
  end

  defp calculate_days_remaining(period_end) do
    case period_end do
      nil -> nil
      end_date ->
        DateTime.diff(end_date, DateTime.utc_now(), :day)
    end
  end

  defp get_upgrade_recommendations(usage_summary, subscription) do
    recommendations = []

    # Check if user is hitting limits
    recommendations = if usage_summary.product_crawls >= usage_summary.limits["product_crawls"] * 0.8 do
      [%{type: "product_crawls", message: "Consider upgrading for more product crawls"} | recommendations]
    else
      recommendations
    end

    recommendations = if usage_summary.ar_views >= usage_summary.limits["ar_views"] * 0.8 do
      [%{type: "ar_views", message: "Consider upgrading for more AR views"} | recommendations]
    else
      recommendations
    end

    recommendations = if usage_summary.model_generations >= usage_summary.limits["model_generations"] * 0.8 do
      [%{type: "model_generations", message: "Consider upgrading for more 3D model generations"} | recommendations]
    else
      recommendations
    end

    # Add tier-specific recommendations
    recommendations = case subscription do
      nil -> [%{type: "subscription", message: "Upgrade from free tier for unlimited access"} | recommendations]
      %{product_id: "com.realproductsize.basic.monthly"} -> [%{type: "subscription", message: "Upgrade to Pro for more features"} | recommendations]
      %{product_id: "com.realproductsize.pro.monthly"} -> [%{type: "subscription", message: "Consider Enterprise for unlimited usage"} | recommendations]
      _ -> recommendations
    end

    recommendations
  end

  @doc """
  Counts daily active users (users with activity today).
  """
  def count_daily_active_users do
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    # Assuming UserUsage tracks daily activity; adjust query as needed
    query = from uu in "user_usages",
      where: fragment("DATE(period_start) >= ? AND DATE(period_start) < ?", ^today, ^tomorrow),
      distinct: true,
      select: uu.user_id

    Repo.aggregate(query, :count, :user_id)
  end

  @doc """
  Counts total sessions ever.
  """
  def count_total_sessions do
    # Assuming sessions table exists; stub for now
    0
  end

  @doc """
  Counts AR sessions.
  """
  def count_ar_sessions do
    # Stub; would query AR session logs
    0
  end

  @doc """
  Counts new users today.
  """
  def count_new_users_today do
    today = Date.utc_today()

    from(u in RealProductSizeBackend.Accounts.User,
      where: fragment("DATE(inserted_at) = ?", ^today)
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Calculates average session duration.
  """
  def avg_session_duration do
    # Stub; would query session logs
    300 # 5 minutes average
  end

  @doc """
  Counts daily active users in date range.
  """
  def count_daily_active_users_by_date_range(_start_date, _end_date) do
    # Stub; would query daily activity logs
    0
  end

  @doc """
  Calculates average session duration in date range.
  """
  def avg_session_duration_by_date_range(_start_date, _end_date) do
    # Stub
    300
  end

  @doc """
  Calculates retention rates for date range.
  """
  def calculate_retention_rates(_start_date, _end_date) do
    # Stub; would calculate cohort retention
    %{day1: 0.8, day7: 0.4, day30: 0.2}
  end

  @doc """
  Gets user sources (referral sources) for date range.
  """
  def get_user_sources(_start_date, _end_date) do
    # Assuming users have source field; stub
    %{direct: 60, social: 20, search: 15, referral: 5}
  end

  @doc """
  Counts currently active users.
  """
  def count_active_users_now do
    # Stub; would query current sessions
    50
  end

  @doc """
  Counts current active sessions.
  """
  def count_current_sessions do
    # Stub
    100
  end

  @doc """
  Test function for development.
  """
  def test_analytics do
    test_user_id = "test-user-123"

    # Test tracking different actions
    track_product_crawl(test_user_id, "https://amazon.com/dp/test", :amazon, 0.85, true)
    track_ar_view(test_user_id, "product-123", 5000)
    track_model_generation(test_user_id, "product-123", 30000, 0.50)

    # Test getting stats
    user_stats = get_user_usage_stats(test_user_id)
    Logger.info("User stats: #{inspect(user_stats)}")

    platform_stats = get_platform_usage_stats()
    Logger.info("Platform stats: #{inspect(platform_stats)}")
  end
end
