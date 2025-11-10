defmodule RealProductSizeBackend.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :external_id, :string
    field :source_url, :string
    field :source_type, :string
    field :title, :string
    field :brand, :string
    field :category, :string
    field :subcategory, :string

    # Dimensions in millimeters
    field :length_mm, :decimal
    field :width_mm, :decimal
    field :height_mm, :decimal
    field :weight_g, :decimal
    field :dimensions_verified, :boolean, default: false

    # Pricing
    field :price_usd, :decimal
    field :original_price_usd, :decimal
    field :currency, :string, default: "USD"
    field :price_updated_at, :utc_datetime

    # Product details
    field :description, :string
    field :features, {:array, :string}
    field :specifications, :map
    field :materials, {:array, :string}
    field :colors, {:array, :string}

    # Images
    field :primary_image_url, :string
    field :image_urls, {:array, :string}
    field :ar_model_url, :string

    # 3D Model Generation
    field :model_generation_status, :string, default: "pending"
    field :model_generated_at, :utc_datetime
    field :model_generation_job_id, :string
    field :tripo_task_id, :string

    # Crawling metadata
    field :crawled_at, :utc_datetime
    field :crawl_version, :string
    field :crawl_quality_score, :decimal
    field :raw_html_snippet, :string

    # Status
    field :is_active, :boolean, default: true
    field :needs_review, :boolean, default: false
    field :review_notes, :string

    # Relationships
    has_many :user_products, RealProductSizeBackend.UserProducts.UserProduct
    has_many :ar_sessions, RealProductSizeBackend.ArSessions.ArSession
    has_many :crawling_history, RealProductSizeBackend.Crawling.CrawlingHistory

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :external_id,
      :source_url,
      :source_type,
      :title,
      :brand,
      :category,
      :subcategory,
      :length_mm,
      :width_mm,
      :height_mm,
      :weight_g,
      :dimensions_verified,
      :price_usd,
      :original_price_usd,
      :currency,
      :price_updated_at,
      :description,
      :features,
      :specifications,
      :materials,
      :colors,
      :primary_image_url,
      :image_urls,
      :ar_model_url,
      :model_generation_status,
      :model_generated_at,
      :model_generation_job_id,
      :tripo_task_id,
      :crawled_at,
      :crawl_version,
      :crawl_quality_score,
      :raw_html_snippet,
      :is_active,
      :needs_review,
      :review_notes
    ])
    |> validate_required([:external_id, :source_url, :source_type, :title])
    |> unique_constraint(:external_id)
    |> validate_url_format(:source_url)
    |> validate_source_type(:source_type)
    |> validate_quality_score(:crawl_quality_score)
    |> set_defaults()
  end

  def dimensions_changeset(product, attrs) do
    product
    |> cast(attrs, [:length_mm, :width_mm, :height_mm, :weight_g, :dimensions_verified])
    |> validate_dimensions()
  end

  # Helper validation functions

  defp validate_url_format(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      url when is_binary(url) ->
        # Allow "manual" as a special case for manually created products
        if url == "manual" or String.match?(url, ~r/^https?:\/\/.+/i) do
          changeset
        else
          add_error(changeset, field, "must be a valid URL starting with http:// or https://, or 'manual' for manually created products")
        end
      _ -> changeset
    end
  end

  defp validate_source_type(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      source_type when is_binary(source_type) ->
        valid_types = ["amazon", "ebay", "walmart", "ikea", "target", "manual", "other"]
        if source_type in valid_types do
          changeset
        else
          add_error(changeset, field, "must be one of: #{Enum.join(valid_types, ", ")}")
        end
      _ -> changeset
    end
  end

  defp validate_quality_score(changeset, field) do
    case get_field(changeset, field) do
      nil -> changeset
      score when is_number(score) ->
        if score >= 0 and score <= 1 do
          changeset
        else
          add_error(changeset, field, "must be between 0 and 1")
        end
      _ -> changeset
    end
  end

  defp validate_dimensions(changeset) do
    changeset
    |> validate_optional_number(:length_mm, greater_than: 0)
    |> validate_optional_number(:width_mm, greater_than: 0)
    |> validate_optional_number(:height_mm, greater_than: 0)
    |> validate_optional_number(:weight_g, greater_than: 0)
  end

  defp validate_optional_number(changeset, field, opts) do
    case get_field(changeset, field) do
      nil -> changeset
      value when is_number(value) ->
        validate_number(changeset, field, opts)
      _ -> changeset
    end
  end

  defp set_defaults(changeset) do
    changeset
    |> put_change(:crawled_at, get_field(changeset, :crawled_at) || DateTime.utc_now())
    |> put_change(:currency, get_field(changeset, :currency) || "USD")
    |> put_change(:model_generation_status, get_field(changeset, :model_generation_status) || "none")
    |> put_change(:is_active, get_field(changeset, :is_active) != false)
    |> put_change(:dimensions_verified, get_field(changeset, :dimensions_verified) || false)
    |> put_change(:needs_review, get_field(changeset, :needs_review) || false)
    |> put_change(:crawl_quality_score, get_field(changeset, :crawl_quality_score) || 0.0)
  end
end
