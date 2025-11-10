defmodule RealProductSizeBackend.Products do
  @moduledoc """
  The Products context.
  """

  import Ecto.Query, warn: false
  alias RealProductSizeBackend.Repo
  alias RealProductSizeBackend.Products.Product

  @doc """
  Gets a single product by ID.
  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Gets a product by external ID.
  """
  def get_product_by_external_id(external_id) do
    Repo.get_by(Product, external_id: external_id)
  end

  @doc """
  Creates a product.
  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a product.
  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates product model generation status.
  """
  def update_product_generation_status(product_id, status) do
    case Repo.get(Product, product_id) do
      nil ->
        {:error, :product_not_found}

      product ->
        product
        |> Product.changeset(%{model_generation_status: status})
        |> Repo.update()
    end
  end

  @doc """
  Updates product dimensions.
  """
  def update_product_dimensions(%Product{} = product, attrs) do
    product
    |> Product.dimensions_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists products with pagination and filters.
  """
  def list_products(opts \\ []) do
    Product
    |> filter_by_category(opts[:category])
    |> filter_by_brand(opts[:brand])
    |> filter_by_dimensions_verified(opts[:dimensions_verified])
    |> filter_by_source_type(opts[:source_type])
    |> filter_by_active(opts[:is_active])
    |> order_by([p], desc: p.crawled_at)
    |> Repo.all()
  end

  @doc """
  Searches products by query.
  """
  def search_products(query, opts \\ []) when is_binary(query) and byte_size(query) > 0 do
    search_term = "%#{query}%"

    Product
    |> where(
      [p],
      ilike(p.title, ^search_term) or
        ilike(p.brand, ^search_term) or
        ilike(p.category, ^search_term) or
        ilike(p.description, ^search_term)
    )
    |> filter_by_category(opts[:category])
    |> filter_by_brand(opts[:brand])
    |> filter_by_dimensions_verified(opts[:dimensions_verified])
    |> order_by([p], desc: p.crawl_quality_score, desc: p.crawled_at)
    |> Repo.all()
  end

  @doc """
  Gets products by category.
  """
  def get_products_by_category(category, _opts \\ []) do
    Product
    |> where([p], p.category == ^category)
    |> filter_by_active(true)
    |> order_by([p], desc: p.crawled_at)
    |> Repo.all()
  end

  @doc """
  Gets products by brand.
  """
  def get_products_by_brand(brand, _opts \\ []) do
    Product
    |> where([p], p.brand == ^brand)
    |> filter_by_active(true)
    |> order_by([p], desc: p.crawled_at)
    |> Repo.all()
  end

  @doc """
  Gets products that need review.
  """
  def get_products_needing_review(_opts \\ []) do
    Product
    |> where([p], p.needs_review == true)
    |> order_by([p], asc: p.crawled_at)
    |> Repo.all()
  end

  @doc """
  Gets product statistics.
  """
  def get_product_stats do
    total_products = Repo.aggregate(Product, :count, :id)
    verified_products = Repo.aggregate(Product, :count, :id, where: [dimensions_verified: true])
    needs_review = Repo.aggregate(Product, :count, :id, where: [needs_review: true])

    %{
      total_products: total_products,
      verified_products: verified_products,
      needs_review: needs_review,
      verification_rate: if(total_products > 0, do: verified_products / total_products, else: 0)
    }
  end

  # Private filter functions

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, category), do: where(query, [p], p.category == ^category)

  defp filter_by_brand(query, nil), do: query
  defp filter_by_brand(query, brand), do: where(query, [p], p.brand == ^brand)

  defp filter_by_dimensions_verified(query, nil), do: query

  defp filter_by_dimensions_verified(query, verified),
    do: where(query, [p], p.dimensions_verified == ^verified)

  defp filter_by_source_type(query, nil), do: query

  defp filter_by_source_type(query, source_type),
    do: where(query, [p], p.source_type == ^source_type)

  defp filter_by_active(query, nil), do: query
  defp filter_by_active(query, is_active), do: where(query, [p], p.is_active == ^is_active)

  @doc """
  Counts total generated models.
  """
  def count_generated_models do
    from(p in Product, where: p.model_generation_status == "completed")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts successful generations.
  """
  def count_successful_generations do
    from(p in Product, where: p.model_generation_status == "completed" and p.generation_success == true)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts failed generations.
  """
  def count_failed_generations do
    from(p in Product, where: p.model_generation_status == "failed")
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets top products by usage in date range.
  """
  def get_top_products_by_usage(start_date, end_date) do
    # Assuming usage logs; stub with top by views or something
    from(p in Product,
      where: p.crawled_at >= ^start_date and p.crawled_at <= ^end_date,
      order_by: [desc: p.view_count],
      limit: 10,
      select: %{id: p.id, title: p.title, views: p.view_count}
    )
    |> Repo.all()
  end

  @doc """
  Calculates generation success rate in date range.
  """
  def calculate_generation_success_rate(start_date, end_date) do
    successful = count_successful_generations_in_range(start_date, end_date)
    total = successful + count_failed_generations_in_range(start_date, end_date)
    if total > 0, do: successful / total, else: 0.0
  end

  @doc """
  Calculates average generation time in date range.
  """
  def calculate_avg_generation_time(start_date, end_date) do
    from(p in Product,
      where: not is_nil(p.generation_start_time) and not is_nil(p.generation_end_time) and
             p.generation_start_time >= ^start_date and p.generation_start_time <= ^end_date,
      select: fragment("(? - ?) / 1000.0", p.generation_end_time, p.generation_start_time)
    )
    |> Repo.aggregate(:avg, 1)
    |> case do
      nil -> 0.0
      avg -> avg
    end
  end

  @doc """
  Gets platform breakdown in date range.
  """
  def get_platform_breakdown(start_date, end_date) do
    from(p in Product,
      where: p.crawled_at >= ^start_date and p.crawled_at <= ^end_date,
      group_by: p.source_type,
      select: %{platform: p.source_type, count: count(p.id)}
    )
    |> Repo.all()
  end

  @doc """
  Counts currently generating models.
  """
  def count_models_generating do
    from(p in Product, where: p.model_generation_status == "generating")
    |> Repo.aggregate(:count, :id)
  end

  defp count_successful_generations_in_range(start_date, end_date) do
    from(p in Product,
      where: p.model_generation_status == "completed" and p.generation_success == true and
             p.crawled_at >= ^start_date and p.crawled_at <= ^end_date
    )
    |> Repo.aggregate(:count, :id)
  end

  defp count_failed_generations_in_range(start_date, end_date) do
    from(p in Product,
      where: p.model_generation_status == "failed" and
             p.crawled_at >= ^start_date and p.crawled_at <= ^end_date
    )
    |> Repo.aggregate(:count, :id)
  end
end
