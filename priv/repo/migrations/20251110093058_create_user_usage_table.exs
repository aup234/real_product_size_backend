defmodule RealProductSizeBackend.Repo.Migrations.CreateUserUsageTable do
  use Ecto.Migration

  def change do
    create table(:user_usage, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :ar_views, :integer, default: 0, null: false
      add :product_crawls, :integer, default: 0, null: false
      add :model_generations, :integer, default: 0, null: false
      add :storage_used, :integer, default: 0, null: false
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_usage, [:user_id])
    create index(:user_usage, [:period_start])
    create unique_index(:user_usage, [:user_id, :period_start])
  end
end
