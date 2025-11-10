defmodule RealProductSizeBackend.Subscriptions.UserUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_usage" do
    field :ar_views, :integer, default: 0
    field :product_crawls, :integer, default: 0
    field :model_generations, :integer, default: 0
    field :storage_used, :integer, default: 0
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime

    belongs_to :user, RealProductSizeBackend.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [
      :user_id,
      :ar_views,
      :product_crawls,
      :model_generations,
      :storage_used,
      :period_start,
      :period_end
    ])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
  end

  def increment_usage(usage, action) do
    case action do
      "ar_view" ->
        change(usage, ar_views: usage.ar_views + 1)

      "product_crawl" ->
        change(usage, product_crawls: usage.product_crawls + 1)

      "model_generation" ->
        change(usage, model_generations: usage.model_generations + 1)

      "storage" ->
        change(usage, storage_used: usage.storage_used + 1)

      _ ->
        usage
    end
  end

  def get_current_usage(user_id) do
    now = DateTime.utc_now()

    start_of_month =
      DateTime.new!(Date.new!(now.year, now.month, 1), Time.new!(0, 0, 0), "Etc/UTC")

    end_of_month =
      DateTime.new!(Date.new!(now.year, now.month + 1, 1), Time.new!(0, 0, 0), "Etc/UTC")
      |> DateTime.add(-1, :second)

    case RealProductSizeBackend.Repo.get_by(__MODULE__,
           user_id: user_id,
           period_start: start_of_month
         ) do
      nil ->
        # Create new usage record for this month
        %__MODULE__{
          user_id: user_id,
          period_start: start_of_month,
          period_end: end_of_month,
          ar_views: 0,
          product_crawls: 0,
          model_generations: 0,
          storage_used: 0
        }

      usage ->
        usage
    end
  end

  def can_perform_action?(user_id, action) do
    usage = get_current_usage(user_id)
    subscription = RealProductSizeBackend.Subscriptions.get_user_subscription(user_id)
    limits = get_limits_for_user(user_id, subscription)

    case action do
      "ar_view" ->
        limits["ar_views"] == -1 or usage.ar_views < limits["ar_views"]

      "product_crawl" ->
        limits["product_crawls"] == -1 or usage.product_crawls < limits["product_crawls"]

      "model_generation" ->
        limits["model_generations"] == -1 or usage.model_generations < limits["model_generations"]

      "storage" ->
        limits["storage"] == -1 or usage.storage_used < limits["storage"]

      _ ->
        true
    end
  end

  def get_limits_for_user(_user_id, subscription) do
    case subscription do
      nil ->
        RealProductSizeBackend.Subscriptions.SubscriptionPlan.free_tier_limits()

      sub ->
        RealProductSizeBackend.Subscriptions.SubscriptionPlan.get_limits_for_product_id(
          sub.product_id
        )
    end
  end
end
