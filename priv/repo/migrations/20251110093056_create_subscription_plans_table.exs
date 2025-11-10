defmodule RealProductSizeBackend.Repo.Migrations.CreateSubscriptionPlansTable do
  use Ecto.Migration

  def change do
    create table(:subscription_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :product_id, :string, null: false
      add :price_monthly, :decimal, precision: 10, scale: 2
      add :price_yearly, :decimal, precision: 10, scale: 2
      add :features, :map
      add :limits, :map
      add :is_active, :boolean, default: true, null: false
      add :sort_order, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscription_plans, [:product_id])
    create index(:subscription_plans, [:is_active])
    create index(:subscription_plans, [:sort_order])
  end
end
