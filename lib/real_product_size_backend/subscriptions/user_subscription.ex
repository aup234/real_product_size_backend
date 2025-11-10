defmodule RealProductSizeBackend.Subscriptions.UserSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_subscriptions" do
    # active, expired, cancelled, pending
    field :status, :string, default: "pending"
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :trial_end, :utc_datetime
    field :product_id, :string
    field :original_transaction_id, :string
    field :transaction_id, :string
    field :receipt_data, :string
    # ios, android
    field :platform, :string
    field :verified_at, :utc_datetime

    belongs_to :user, RealProductSizeBackend.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :status,
      :current_period_start,
      :current_period_end,
      :cancel_at_period_end,
      :trial_end,
      :product_id,
      :original_transaction_id,
      :transaction_id,
      :receipt_data,
      :platform,
      :verified_at
    ])
    |> validate_required([:user_id, :product_id])
    |> foreign_key_constraint(:user_id)
  end

  def is_active?(subscription) do
    subscription.status == "active" and
      (subscription.current_period_end == nil or
         DateTime.compare(subscription.current_period_end, DateTime.utc_now()) == :gt)
  end

  def is_expired?(subscription) do
    subscription.current_period_end != nil and
      DateTime.compare(subscription.current_period_end, DateTime.utc_now()) == :lt
  end

  def is_cancelled?(subscription) do
    subscription.status == "cancelled"
  end

  def is_pending?(subscription) do
    subscription.status == "pending"
  end
end
