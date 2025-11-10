defmodule RealProductSizeBackend.Repo.Migrations.CreateProductsTable do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :external_id, :string, null: false
      add :source_url, :text, null: false
      add :source_type, :string, null: false
      add :title, :string, null: false
      add :brand, :string
      add :category, :string
      add :subcategory, :string

      # Dimensions in millimeters
      add :length_mm, :decimal, precision: 10, scale: 2
      add :width_mm, :decimal, precision: 10, scale: 2
      add :height_mm, :decimal, precision: 10, scale: 2
      add :weight_g, :decimal, precision: 10, scale: 2
      add :dimensions_verified, :boolean, default: false

      # Pricing
      add :price_usd, :decimal, precision: 10, scale: 2
      add :original_price_usd, :decimal, precision: 10, scale: 2
      add :currency, :string, default: "USD"
      add :price_updated_at, :utc_datetime

      # Product details
      add :description, :text
      add :features, {:array, :string}
      add :specifications, :map
      add :materials, {:array, :string}
      add :colors, {:array, :string}

      # Images
      add :primary_image_url, :text
      add :image_urls, {:array, :text}
      add :ar_model_url, :text

      # Crawling metadata
      add :crawled_at, :utc_datetime, null: false
      add :crawl_version, :string
      add :crawl_quality_score, :decimal, precision: 3, scale: 2
      add :raw_html_snippet, :text

      # Status
      add :is_active, :boolean, default: true
      add :needs_review, :boolean, default: false
      add :review_notes, :text

      timestamps(type: :utc_datetime)
    end

    # Indexes for performance
    create unique_index(:products, [:external_id])
    create index(:products, [:source_url])
    create index(:products, [:source_type])
    create index(:products, [:category])
    create index(:products, [:crawled_at])
    create index(:products, [:dimensions_verified])
    create index(:products, [:crawl_quality_score])
    create index(:products, [:is_active])
  end
end
