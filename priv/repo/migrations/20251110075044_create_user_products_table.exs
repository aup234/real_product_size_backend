defmodule RealProductSizeBackend.Repo.Migrations.CreateUserProductsTable do
  use Ecto.Migration

  def change do
    create table(:user_products, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :notes, :text
      add :tags, {:array, :string}
      add :favorite, :boolean, default: false
      add :ar_view_count, :integer, default: 0
      add :last_ar_view_at, :utc_datetime

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:user_products, [:user_id, :product_id])
    create index(:user_products, [:user_id])
    create index(:user_products, [:product_id])
    create index(:user_products, [:favorite])
    create index(:user_products, [:ar_view_count])
    create index(:user_products, [:last_ar_view_at])
  end
end
