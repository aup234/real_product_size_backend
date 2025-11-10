defmodule RealProductSizeBackendWeb.Api.ProductJSON do
  @doc """
  Renders a list of products.
  """
  def index(%{products: products}) do
    %{data: for(product <- products, do: data(product))}
  end

  @doc """
  Renders a single product.
  """
  def show(%{product: product}) do
    %{data: data(product)}
  end

  defp data(product) do
    # Handle both normalized (camelCase) and raw DB (snake_case) formats
    # Prioritize camelCase from DataAdapter for Flutter compatibility

    id = Map.get(product, :id)
    name = Map.get(product, :name) || Map.get(product, :title)

    # Image handling - prioritize camelCase from normalized data
    image_urls = Map.get(product, :imageUrls) ||
                 (Map.get(product, :image_urls) || []) |> normalize_image_list_in_view(Map.get(product, :primary_image_url))

    %{
      id: id,
      name: name,
      imageUrls: image_urls,
      dimensions: format_dimensions(product),
      dimensionsStructured: build_structured_dimensions(product),
      # Flutter expects array, not Set
      selectedImageIndices: Map.get(product, :selectedImageIndices) || [0],
      displayedImageIndex: Map.get(product, :displayedImageIndex) || 0,
      # Additional backend fields for reference (optional)
      external_id: Map.get(product, :external_id),
      source_url: Map.get(product, :source_url),
      source_type: Map.get(product, :source_type),
      brand: Map.get(product, :brand),
      category: Map.get(product, :category),
      subcategory: Map.get(product, :subcategory),
      price_usd: Map.get(product, :price_usd),
      currency: Map.get(product, :currency),
      description: Map.get(product, :description),
      features: Map.get(product, :features) || [],
      materials: Map.get(product, :materials) || [],
      colors: Map.get(product, :colors) || [],
      crawled_at: Map.get(product, :crawled_at),
      crawl_quality_score: Map.get(product, :crawl_quality_score)
    }
  end

  # Format dimensions as a human-readable string
  defp format_dimensions(product) do
    # Check if product already has formatted dimensions (from Flutter-compatible format)
    case Map.get(product, :dimensions) do
      nil ->
        # Fallback to individual dimension fields
        length = Map.get(product, :length_mm)
        width = Map.get(product, :width_mm)
        height = Map.get(product, :height_mm)

        case {length, width, height} do
          {l, w, h} when not is_nil(l) and not is_nil(w) and not is_nil(h) ->
            "#{ensure_float(l)}mm × #{ensure_float(w)}mm × #{ensure_float(h)}mm"

          _ ->
            "Dimensions not available"
        end

      dimensions_string ->
        dimensions_string
    end
  end

  # Build structured dimensions object
  defp build_structured_dimensions(product) do
    # Check if product already has structured dimensions (from Flutter-compatible format)
    case Map.get(product, :dimensionsStructured) do
      nil ->
        # Fallback to individual dimension fields
        length = Map.get(product, :length_mm)
        width = Map.get(product, :width_mm)
        height = Map.get(product, :height_mm)

        case {length, width, height} do
          {l, w, h} when not is_nil(l) and not is_nil(w) and not is_nil(h) ->
            %{
              length: ensure_float(l),
              width: ensure_float(w),
              height: ensure_float(h),
              unit: "mm"
            }

          _ ->
            %{
              length: 0.0,
              width: 0.0,
              height: 0.0,
              unit: "mm"
            }
        end

      structured_dimensions ->
        structured_dimensions
    end
  end

  # Helper to normalize images in view (similar to DataAdapter)
  # Helper function to ensure values are floats
  defp ensure_float(value) when is_float(value), do: value
  defp ensure_float(value) when is_integer(value), do: value * 1.0
  defp ensure_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp ensure_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_value, _} -> float_value
      :error -> 0.0
    end
  end
  defp ensure_float(_), do: 0.0

  defp normalize_image_list_in_view(image_urls, primary_image_url) when is_list(image_urls) do
    images = Enum.filter(image_urls, &(&1 != nil && &1 != ""))

    case primary_image_url do
      nil -> images
      url when is_binary(url) and url != "" ->
        if Enum.member?(images, url), do: images, else: [url | images]
      _ -> images
    end
  end

  defp normalize_image_list_in_view(_, _), do: []
end
