defmodule RealProductSizeBackendWeb.Api.UsageController do
  use RealProductSizeBackendWeb, :controller

  alias RealProductSizeBackend.Subscriptions

  action_fallback RealProductSizeBackendWeb.FallbackController

  def track(conn, %{"action" => action}) do
    user_id = conn.assigns.current_user.id

    case Subscriptions.track_usage(user_id, action) do
      {:ok, _usage} ->
        json(conn, %{status: "tracked"})

      {:error, :limit_exceeded} ->
        conn
        |> put_status(429)
        |> json(%{error: "Usage limit exceeded for #{action}"})

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to track usage", details: changeset.errors})
    end
  end

  def check(conn, %{"action" => action}) do
    user_id = conn.assigns.current_user.id
    can_perform = Subscriptions.check_usage_limit(user_id, action)

    json(conn, %{can_perform: can_perform})
  end

  def summary(conn, _params) do
    user_id = conn.assigns.current_user.id
    summary = Subscriptions.get_usage_summary(user_id)

    json(conn, summary)
  end
end
