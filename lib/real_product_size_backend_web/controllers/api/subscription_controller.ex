defmodule RealProductSizeBackendWeb.Api.SubscriptionController do
  use RealProductSizeBackendWeb, :controller

  alias RealProductSizeBackend.Subscriptions

  action_fallback RealProductSizeBackendWeb.FallbackController

  def verify(conn, %{
        "product_id" => product_id,
        "transaction_id" => transaction_id,
        "receipt_data" => receipt_data,
        "platform" => platform
      }) do
    user_id = conn.assigns.current_user.id

    case Subscriptions.verify_purchase(
           user_id,
           product_id,
           transaction_id,
           receipt_data,
           platform
         ) do
      {:ok, subscription} ->
        json(conn, %{
          status: "verified",
          subscription: %{
            id: subscription.id,
            user_id: subscription.user_id,
            product_id: subscription.product_id,
            status: subscription.status,
            purchase_date: subscription.current_period_start,
            expiration_date: subscription.current_period_end,
            auto_renewing: not subscription.cancel_at_period_end,
            original_transaction_id: subscription.original_transaction_id,
            transaction_id: subscription.transaction_id,
            created_at: subscription.inserted_at,
            updated_at: subscription.updated_at
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to verify purchase", details: changeset.errors})
    end
  end

  def current(conn, _params) do
    user_id = conn.assigns.current_user.id

    case Subscriptions.get_user_subscription(user_id) do
      nil ->
        json(conn, %{subscription: nil})

      subscription ->
        json(conn, %{
          subscription: %{
            id: subscription.id,
            user_id: subscription.user_id,
            product_id: subscription.product_id,
            status: subscription.status,
            purchase_date: subscription.current_period_start,
            expiration_date: subscription.current_period_end,
            auto_renewing: not subscription.cancel_at_period_end,
            original_transaction_id: subscription.original_transaction_id,
            transaction_id: subscription.transaction_id,
            created_at: subscription.inserted_at,
            updated_at: subscription.updated_at
          }
        })
    end
  end

  def plans(conn, _params) do
    plans = Subscriptions.list_subscription_plans()

    json(conn, %{
      plans:
        Enum.map(plans, fn plan ->
          %{
            id: plan.id,
            name: plan.name,
            description: plan.description,
            product_id: plan.product_id,
            price_monthly: plan.price_monthly,
            price_yearly: plan.price_yearly,
            features: plan.features,
            limits: plan.limits,
            is_active: plan.is_active
          }
        end)
    })
  end
end
