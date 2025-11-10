defmodule RealProductSizeBackend.UserProducts do
  @moduledoc """
  The UserProducts context.
  """

  import Ecto.Query, warn: false
  alias RealProductSizeBackend.Repo
  alias RealProductSizeBackend.UserProducts.UserProduct

  @doc """
  Gets user products for a specific user.
  """
  def list_user_products(user_id, opts \\ []) do
    require Logger
    Logger.info("Querying user products for user_id: #{inspect(user_id)}")

    query =
      UserProduct
      |> where([up], up.user_id == ^user_id)
      |> filter_by_favorite(opts[:favorite])
      |> filter_by_tags(opts[:tags])
      |> preload([:product])
      |> order_by([up], desc: up.updated_at)

    Logger.info("Query: #{inspect(query)}")

    result = Repo.all(query)
    Logger.info("Found #{length(result)} user products")
    result
  end

  @doc """
  Gets a single user product.
  """
  def get_user_product!(id), do: Repo.get!(UserProduct, id)

  @doc """
  Gets user product by user and product IDs.
  """
  def get_user_product_by_user_and_product(user_id, product_id) do
    Repo.get_by(UserProduct, user_id: user_id, product_id: product_id)
  end

  @doc """
  Creates a user product relationship.
  """
  def create_user_product(attrs \\ %{}) do
    require Logger
    Logger.info("Creating user product with attrs: #{inspect(attrs)}")

    result =
      %UserProduct{}
      |> UserProduct.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user_product} ->
        Logger.info("Successfully created user product: #{inspect(user_product)}")
        result

      {:error, changeset} ->
        Logger.error("Failed to create user product: #{inspect(changeset.errors)}")
        result
    end
  end

  @doc """
  Updates a user product.
  """
  def update_user_product(%UserProduct{} = user_product, attrs) do
    user_product
    |> UserProduct.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user product.
  """
  def delete_user_product(%UserProduct{} = user_product) do
    Repo.delete(user_product)
  end

  @doc """
  Toggles favorite status for a user product.
  """
  def toggle_favorite(user_id, product_id) do
    case get_user_product_by_user_and_product(user_id, product_id) do
      nil ->
        # Create new user product as favorite
        create_user_product(%{
          user_id: user_id,
          product_id: product_id,
          favorite: true
        })

      user_product ->
        # Toggle existing favorite status
        update_user_product(user_product, %{favorite: !user_product.favorite})
    end
  end

  @doc """
  Updates AR view count for a user product.
  """
  def increment_ar_view_count(user_id, product_id) do
    case get_user_product_by_user_and_product(user_id, product_id) do
      nil ->
        # Create new user product with AR view
        create_user_product(%{
          user_id: user_id,
          product_id: product_id,
          ar_view_count: 1,
          last_ar_view_at: DateTime.utc_now()
        })

      user_product ->
        # Increment existing AR view count
        user_product
        |> UserProduct.increment_ar_view_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Gets favorite products for a user.
  """
  def get_favorite_products(user_id, _opts \\ []) do
    UserProduct
    |> where([up], up.user_id == ^user_id and up.favorite == true)
    |> preload([:product])
    |> order_by([up], desc: up.updated_at)
    |> Repo.all()
  end

  @doc """
  Gets recently viewed products for a user.
  """
  def get_recently_viewed_products(user_id, limit \\ 10) do
    UserProduct
    |> where([up], up.user_id == ^user_id and not is_nil(up.last_ar_view_at))
    |> order_by([up], desc: up.last_ar_view_at)
    |> limit(^limit)
    |> preload([:product])
    |> Repo.all()
  end

  @doc """
  Gets user product statistics.
  """
  def get_user_product_stats(user_id) do
    total_products =
      UserProduct
      |> where([up], up.user_id == ^user_id)
      |> Repo.aggregate(:count, :id)

    favorite_products =
      UserProduct
      |> where([up], up.user_id == ^user_id and up.favorite == true)
      |> Repo.aggregate(:count, :id)

    total_ar_views =
      UserProduct
      |> where([up], up.user_id == ^user_id)
      |> Repo.aggregate(:sum, :ar_view_count)

    %{
      total_products: total_products,
      favorite_products: favorite_products,
      total_ar_views: total_ar_views || 0,
      favorite_rate: if(total_products > 0, do: favorite_products / total_products, else: 0)
    }
  end

  # Private filter functions

  defp filter_by_favorite(query, nil), do: query
  defp filter_by_favorite(query, favorite), do: where(query, [up], up.favorite == ^favorite)

  defp filter_by_tags(query, nil), do: query

  defp filter_by_tags(query, tags) when is_list(tags) do
    where(query, [up], fragment("? && ?", up.tags, ^tags))
  end

  defp filter_by_tags(query, tag) when is_binary(tag) do
    where(query, [up], fragment("? @> ?", up.tags, ^[tag]))
  end
end
