defmodule RealProductSizeBackend.Repo.Migrations.CreateUserSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:user_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :status, :string, default: "pending", null: false
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false, null: false
      add :trial_end, :utc_datetime
      add :product_id, :string, null: false
      add :original_transaction_id, :string
      add :transaction_id, :string
      add :receipt_data, :text
      add :platform, :string
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:user_subscriptions, [:user_id])
    create index(:user_subscriptions, [:status])
    create index(:user_subscriptions, [:product_id])
    create index(:user_subscriptions, [:transaction_id])
    create index(:user_subscriptions, [:original_transaction_id])
  end
end
