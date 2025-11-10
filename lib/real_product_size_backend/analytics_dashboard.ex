defmodule RealProductSizeBackend.AnalyticsDashboard do
  @moduledoc """
  Analytics dashboard and business intelligence system.

  This module provides comprehensive analytics for:
  - Crawling performance metrics
  - User behavior analysis
  - Platform usage statistics
  - Error tracking and resolution
  - Business intelligence insights
  """

  require Logger

  @doc """
  Gets comprehensive analytics dashboard data.

  Returns dashboard data map
  """
  def get_dashboard_data do
    %{
      overview: get_overview_metrics(),
      crawling_stats: get_crawling_analytics(),
      user_analytics: get_user_analytics(),
      platform_analytics: get_platform_analytics(),
      error_analytics: get_error_analytics(),
      business_metrics: get_business_metrics(),
      performance_metrics: get_performance_metrics()
    }
  end

  @doc """
  Gets overview metrics for the dashboard.

  Returns overview metrics map
  """
  def get_overview_metrics do
    # In production, these would be calculated from actual data
    %{
      total_products: 1250,
      total_users: 500,
      total_crawls_today: 45,
      success_rate: 0.87,
      average_response_time: 2.3,
      cache_hit_rate: 0.65,
      active_subscriptions: 150,
      revenue_this_month: 2500.0
    }
  end

  @doc """
  Gets crawling analytics and performance metrics.

  Returns crawling analytics map
  """
  def get_crawling_analytics do
    %{
      total_crawls: 1250,
      successful_crawls: 1087,
      failed_crawls: 163,
      success_rate: 0.87,
      average_crawl_time: 2.3,
      platform_breakdown: %{
        amazon: %{crawls: 800, success_rate: 0.85, avg_time: 2.1},
        ikea: %{crawls: 300, success_rate: 0.92, avg_time: 1.8},
        walmart: %{crawls: 100, success_rate: 0.78, avg_time: 2.8},
        target: %{crawls: 50, success_rate: 0.80, avg_time: 2.5}
      },
      quality_distribution: %{
        excellent: 200,
        very_good: 400,
        good: 350,
        fair: 200,
        poor: 100
      },
      hourly_distribution: generate_hourly_distribution(),
      daily_trends: generate_daily_trends()
    }
  end

  @doc """
  Gets user analytics and behavior insights.

  Returns user analytics map
  """
  def get_user_analytics do
    %{
      total_users: 500,
      active_users_today: 45,
      new_users_this_week: 25,
      user_retention_rate: 0.75,
      average_session_duration: 8.5,
      subscription_distribution: %{
        free: 350,
        basic: 100,
        pro: 40,
        enterprise: 10
      },
      user_activity: %{
        most_active_hours: [9, 10, 11, 14, 15, 16, 19, 20],
        peak_usage_days: ["Monday", "Tuesday", "Wednesday"],
        average_crawls_per_user: 2.5,
        most_popular_platforms: [:amazon, :ikea, :walmart]
      },
      user_feedback: %{
        total_feedback: 45,
        resolved_feedback: 38,
        pending_feedback: 7,
        average_resolution_time: 2.5
      }
    }
  end

  @doc """
  Gets platform-specific analytics.

  Returns platform analytics map
  """
  def get_platform_analytics do
    %{
      amazon: %{
        total_crawls: 800,
        success_rate: 0.85,
        average_quality: 0.75,
        common_errors: ["timeout", "validation_failed", "rate_limit"],
        ar_suitability_rate: 0.78,
        average_dimensions_available: 0.82
      },
      ikea: %{
        total_crawls: 300,
        success_rate: 0.92,
        average_quality: 0.88,
        common_errors: ["timeout", "validation_failed"],
        ar_suitability_rate: 0.95,
        average_dimensions_available: 0.95
      },
      walmart: %{
        total_crawls: 100,
        success_rate: 0.78,
        average_quality: 0.70,
        common_errors: ["timeout", "validation_failed", "platform_error"],
        ar_suitability_rate: 0.72,
        average_dimensions_available: 0.75
      },
      target: %{
        total_crawls: 50,
        success_rate: 0.80,
        average_quality: 0.72,
        common_errors: ["timeout", "validation_failed"],
        ar_suitability_rate: 0.75,
        average_dimensions_available: 0.78
      }
    }
  end

  @doc """
  Gets error analytics and resolution metrics.

  Returns error analytics map
  """
  def get_error_analytics do
    %{
      total_errors: 163,
      error_types: %{
        network_error: 45,
        validation_error: 38,
        platform_error: 25,
        rate_limit_error: 20,
        timeout_error: 20,
        unknown_error: 15
      },
      error_resolution: %{
        auto_resolved: 120,
        user_feedback_resolved: 25,
        manual_resolution: 18
      },
      error_trends: %{
        decreasing_errors: true,
        most_common_error: :network_error,
        resolution_rate: 0.85
      },
      platform_error_rates: %{
        amazon: 0.15,
        ikea: 0.08,
        walmart: 0.22,
        target: 0.20
      }
    }
  end

  @doc """
  Gets business metrics and KPIs.

  Returns business metrics map
  """
  def get_business_metrics do
    %{
      revenue: %{
        monthly_recurring_revenue: 2500.0,
        revenue_growth_rate: 0.15,
        average_revenue_per_user: 5.0,
        churn_rate: 0.05
      },
      subscriptions: %{
        total_active: 150,
        new_this_month: 25,
        cancelled_this_month: 8,
        conversion_rate: 0.12
      },
      usage: %{
        total_crawls_this_month: 1250,
        average_crawls_per_user: 2.5,
        peak_usage_hour: 14,
        usage_growth_rate: 0.20
      },
      costs: %{
        ai_api_costs: 150.0,
        infrastructure_costs: 200.0,
        total_operational_costs: 350.0,
        cost_per_crawl: 0.28
      }
    }
  end

  @doc """
  Gets performance metrics and system health.

  Returns performance metrics map
  """
  def get_performance_metrics do
    %{
      response_times: %{
        average: 2.3,
        p50: 1.8,
        p95: 5.2,
        p99: 8.7
      },
      cache_performance: %{
        hit_rate: 0.65,
        miss_rate: 0.35,
        average_cache_time: 0.1,
        cache_size: 500
      },
      system_health: %{
        uptime: 0.999,
        error_rate: 0.13,
        memory_usage: 0.75,
        cpu_usage: 0.45
      },
      scalability: %{
        concurrent_users: 45,
        max_concurrent_users: 100,
        queue_length: 5,
        processing_capacity: 0.45
      }
    }
  end

  @doc """
  Gets real-time analytics data.

  Returns real-time data map
  """
  def get_realtime_analytics do
    %{
      current_active_users: 12,
      crawls_in_last_hour: 8,
      errors_in_last_hour: 1,
      cache_hit_rate_last_hour: 0.70,
      average_response_time_last_hour: 2.1,
      system_status: :healthy,
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Gets analytics for a specific time range.

  Returns time-range analytics map
  """
  def get_time_range_analytics(start_date, end_date) do
    # In production, this would query the database for the specified time range
    %{
      start_date: start_date,
      end_date: end_date,
      total_crawls: 250,
      successful_crawls: 220,
      failed_crawls: 30,
      success_rate: 0.88,
      unique_users: 45,
      average_crawls_per_user: 5.6,
      platform_breakdown: %{
        amazon: 150,
        ikea: 60,
        walmart: 25,
        target: 15
      },
      error_breakdown: %{
        network_error: 12,
        validation_error: 10,
        platform_error: 5,
        timeout_error: 3
      }
    }
  end

  @doc """
  Gets user-specific analytics.

  Returns user analytics map
  """
  def get_user_analytics(user_id) do
    # In production, this would query user-specific data
    %{
      user_id: user_id,
      total_crawls: 15,
      successful_crawls: 13,
      failed_crawls: 2,
      success_rate: 0.87,
      favorite_platforms: [:amazon, :ikea],
      average_quality_score: 0.82,
      last_crawl: DateTime.utc_now() |> DateTime.add(-2, :hour),
      subscription_tier: :basic,
      usage_this_month: %{
        crawls: 15,
        ar_views: 25,
        model_generations: 3
      }
    }
  end

  # Private functions

  defp generate_hourly_distribution do
    # Generate mock hourly distribution data
    Enum.map(0..23, fn hour ->
      base_usage = if hour >= 9 and hour <= 17, do: 10, else: 3
      random_factor = :rand.uniform(5)
      {hour, base_usage + random_factor}
    end)
    |> Enum.into(%{})
  end

  defp generate_daily_trends do
    # Generate mock daily trends for the last 7 days
    Enum.map(0..6, fn days_ago ->
      date = Date.add(Date.utc_today(), -days_ago)
      crawls = :rand.uniform(50) + 20
      {date, crawls}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Exports analytics data in various formats.

  Returns exported data
  """
  def export_analytics(format \\ :json) do
    data = get_dashboard_data()

    case format do
      :json ->
        Jason.encode!(data)

      :csv ->
        export_to_csv(data)

      :excel ->
        export_to_excel(data)

      _ ->
        {:error, "Unsupported format: #{format}"}
    end
  end

  defp export_to_csv(data) do
    # Simple CSV export implementation
    "Metric,Value\n" <>
    "Total Products,#{data.overview.total_products}\n" <>
    "Total Users,#{data.overview.total_users}\n" <>
    "Success Rate,#{data.overview.success_rate}\n" <>
    "Cache Hit Rate,#{data.overview.cache_hit_rate}\n"
  end

  defp export_to_excel(_data) do
    # Excel export would require additional dependencies
    {:error, "Excel export not implemented"}
  end

  @doc """
  Test function for development.
  """
  def test_analytics do
    # Test dashboard data
    dashboard = get_dashboard_data()
    Logger.info("Dashboard data: #{inspect(dashboard)}")

    # Test real-time analytics
    realtime = get_realtime_analytics()
    Logger.info("Real-time analytics: #{inspect(realtime)}")

    # Test user analytics
    user_analytics = get_user_analytics("test-user-123")
    Logger.info("User analytics: #{inspect(user_analytics)}")

    # Test export
    case export_analytics(:json) do
      {:ok, _json_data} ->
        Logger.info("JSON export successful")
      {:error, reason} ->
        Logger.error("JSON export failed: #{reason}")
    end
  end
end
