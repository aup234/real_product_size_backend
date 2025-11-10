defmodule RealProductSizeBackend.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """

  import Ecto.Query, warn: false
  alias RealProductSizeBackend.Repo
  alias RealProductSizeBackend.Subscriptions.{SubscriptionPlan, UserSubscription, UserUsage}

  # User Subscriptions

  def get_user_subscription(user_id) do
    UserSubscription
    |> where([s], s.user_id == ^user_id)
    |> where([s], s.status in ["active", "pending"])
    |> order_by([s], desc: s.inserted_at)
    |> first()
    |> Repo.one()
  end

  def create_user_subscription(attrs \\ %{}) do
    %UserSubscription{}
    |> UserSubscription.changeset(attrs)
    |> Repo.insert()
  end

  def update_user_subscription(%UserSubscription{} = subscription, attrs) do
    subscription
    |> UserSubscription.changeset(attrs)
    |> Repo.update()
  end

  def verify_purchase(user_id, product_id, transaction_id, receipt_data, platform) do
    # In a real implementation, you would verify the receipt with Apple/Google
    # For now, we'll create a mock verification

    now = DateTime.utc_now()

    period_end =
      case product_id do
        product_id
        when product_id in [
               "com.realproductsize.basic.monthly",
               "com.realproductsize.pro.monthly",
               "com.realproductsize.enterprise.monthly"
             ] ->
          DateTime.add(now, 30, :day)

        product_id
        when product_id in ["com.realproductsize.basic.yearly", "com.realproductsize.pro.yearly"] ->
          DateTime.add(now, 365, :day)

        _ ->
          DateTime.add(now, 30, :day)
      end

    subscription_attrs = %{
      user_id: user_id,
      product_id: product_id,
      status: "active",
      current_period_start: now,
      current_period_end: period_end,
      transaction_id: transaction_id,
      original_transaction_id: transaction_id,
      receipt_data: receipt_data,
      platform: platform,
      verified_at: now
    }

    case create_user_subscription(subscription_attrs) do
      {:ok, subscription} ->
        {:ok, subscription}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Usage Tracking

  def track_usage(user_id, action) do
    usage = UserUsage.get_current_usage(user_id)

    case UserUsage.can_perform_action?(user_id, action) do
      true ->
        usage
        |> UserUsage.increment_usage(action)
        |> Repo.insert_or_update()

      false ->
        {:error, :limit_exceeded}
    end
  end

  def check_usage_limit(user_id, action) do
    UserUsage.can_perform_action?(user_id, action)
  end

  def get_usage_summary(user_id) do
    usage = UserUsage.get_current_usage(user_id)
    subscription = get_user_subscription(user_id)
    limits = UserUsage.get_limits_for_user(user_id, subscription)

    %{
      ar_views: usage.ar_views,
      product_crawls: usage.product_crawls,
      model_generations: usage.model_generations,
      storage_used: usage.storage_used,
      limits: limits,
      period_start: usage.period_start,
      period_end: usage.period_end,
      subscription_plan: if(subscription, do: subscription.product_id, else: nil)
    }
  end

  # Subscription Plans

  def list_subscription_plans do
    SubscriptionPlan
    |> where([p], p.is_active == true)
    |> order_by([p], asc: p.sort_order)
    |> Repo.all()
  end

  def get_subscription_plan!(id), do: Repo.get!(SubscriptionPlan, id)

  def create_subscription_plan(attrs \\ %{}) do
    %SubscriptionPlan{}
    |> SubscriptionPlan.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscription_plan(%SubscriptionPlan{} = plan, attrs) do
    plan
    |> SubscriptionPlan.changeset(attrs)
    |> Repo.update()
  end

  def delete_subscription_plan(%SubscriptionPlan{} = plan) do
    Repo.delete(plan)
  end

  def change_subscription_plan(%SubscriptionPlan{} = plan, attrs \\ %{}) do
    SubscriptionPlan.changeset(plan, attrs)
  end

  @doc """
  Counts active subscriptions.
  """
  def count_active_subscriptions do
    from(s in UserSubscription, where: s.status == "active")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts subscriptions by tier.
  """
  def count_subscriptions_by_tier(tier) do
    from(s in UserSubscription,
      where: s.status == "active",
      where: fragment("product_id LIKE ?", ^"%#{tier}%")
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Calculates monthly recurring revenue.
  """
  def calculate_mrr do
    from(s in UserSubscription,
      where: s.status == "active",
      where: fragment("product_id LIKE ?", "%monthly%"),
      select: s.price_monthly
    )
    |> Repo.aggregate(:sum, :price_monthly, as: :decimal)
    |> case do
      nil -> Decimal.new(0)
      sum -> sum
    end
  end

  @doc """
  Calculates total revenue.
  """
  def calculate_total_revenue do
    from(s in UserSubscription, select: s.total_revenue)
    |> Repo.aggregate(:sum, :total_revenue, as: :decimal)
    |> case do
      nil -> Decimal.new(0)
      sum -> sum
    end
  end

  @doc """
  Calculates revenue by date range.
  """
  def calculate_revenue_by_date_range(start_date, end_date) do
    from(s in UserSubscription,
      where: s.verified_at >= ^start_date and s.verified_at <= ^end_date,
      select: s.price_paid
    )
    |> Repo.aggregate(:sum, :price_paid, as: :decimal)
    |> case do
      nil -> Decimal.new(0)
      sum -> sum
    end
  end

  @doc """
  Calculates subscription revenue in date range.
  """
  def calculate_subscription_revenue(start_date, end_date) do
    from(s in UserSubscription,
      where: s.status == "active" and
             s.current_period_start >= ^start_date and s.current_period_start <= ^end_date,
      select: s.price_monthly
    )
    |> Repo.aggregate(:sum, :price_monthly, as: :decimal)
    |> case do
      nil -> Decimal.new(0)
      sum -> sum
    end
  end

  @doc """
  Calculates churn revenue in date range (lost revenue from cancellations).
  """
  def calculate_churn_revenue(start_date, end_date) do
    from(s in UserSubscription,
      where: s.status == "cancelled" and
             s.cancelled_at >= ^start_date and s.cancelled_at <= ^end_date,
      select: s.price_monthly
    )
    |> Repo.aggregate(:sum, :price_monthly, as: :decimal)
    |> case do
      nil -> Decimal.new(0)
      sum -> sum
    end
  end

  @doc """
  Counts new subscriptions in date range.
  """
  def count_new_subscriptions(start_date, end_date) do
    from(s in UserSubscription,
      where: s.status == "active" and
             s.verified_at >= ^start_date and s.verified_at <= ^end_date
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts cancellations in date range.
  """
  def count_cancellations(start_date, end_date) do
    from(s in UserSubscription,
      where: s.status == "cancelled" and
             s.cancelled_at >= ^start_date and s.cancelled_at <= ^end_date
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Calculates churn rate in date range.
  """
  def calculate_churn_rate(start_date, end_date) do
    new_subs = count_new_subscriptions(start_date, end_date)
    cancels = count_cancellations(start_date, end_date)
    if new_subs > 0, do: cancels / new_subs, else: 0.0
  end

  @doc """
  Calculates lifetime value (average revenue per user).
  """
  def calculate_ltv do
    total_revenue = calculate_total_revenue()
    total_users = RealProductSizeBackend.Accounts.count_users()
    if total_users > 0, do: Decimal.div(total_revenue, Decimal.new(total_users)), else: Decimal.new(0)
  end
end
