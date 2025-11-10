defmodule RealProductSizeBackendWeb.Plugs.UsageLimit do
  @moduledoc """
  Plug for checking usage limits before processing requests.

  This plug can be used to enforce subscription-based limits on various actions
  like crawling, AR viewing, model generation, etc.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  alias RealProductSizeBackend.Subscriptions

  def init(opts), do: opts

  def call(conn, opts) do
    action = Keyword.get(opts, :action, "general")
    user_id = conn.assigns.current_user.id

    case Subscriptions.check_usage_limit(user_id, action) do
      true ->
        conn

      false ->
        # Get usage summary to show current limits
        usage_summary = Subscriptions.get_usage_summary(user_id)

        conn
        |> put_status(429)
        |> json(%{
          error: "Usage limit exceeded",
          reason: "You have reached your monthly #{action} limit",
          current_usage: get_current_usage_for_action(usage_summary, action),
          limit: get_limit_for_action(usage_summary.limits, action),
          upgrade_required: true,
          usage_summary: %{
            ar_views: usage_summary.ar_views,
            product_crawls: usage_summary.product_crawls,
            model_generations: usage_summary.model_generations,
            storage_used: usage_summary.storage_used,
            limits: usage_summary.limits,
            subscription_plan: usage_summary.subscription_plan
          }
        })
        |> halt()
    end
  end

  defp get_current_usage_for_action(usage_summary, action) do
    case action do
      "ar_view" -> usage_summary.ar_views
      "product_crawl" -> usage_summary.product_crawls
      "model_generation" -> usage_summary.model_generations
      "storage" -> usage_summary.storage_used
      _ -> 0
    end
  end

  defp get_limit_for_action(limits, action) do
    case action do
      "ar_view" -> limits["ar_views"]
      "product_crawl" -> limits["product_crawls"]
      "model_generation" -> limits["model_generations"]
      "storage" -> limits["storage"]
      _ -> -1
    end
  end

  @doc """
  Helper function to check if a user can perform an action.
  """
  def can_perform_action?(user_id, action) do
    Subscriptions.check_usage_limit(user_id, action)
  end

  @doc """
  Helper function to get usage summary for a user.
  """
  def get_usage_summary(user_id) do
    Subscriptions.get_usage_summary(user_id)
  end

  @doc """
  Helper function to track usage after successful action.
  """
  def track_usage(user_id, action) do
    Subscriptions.track_usage(user_id, action)
  end
end
