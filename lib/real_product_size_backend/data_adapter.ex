defmodule RealProductSizeBackend.DataAdapter do
  @moduledoc """
  Unified data adapter for consistent data structures between mock and real services.

  This module ensures that both mock and real services return data in the exact format
  expected by the Flutter app, eliminating inconsistencies and integration issues.
  """

  require Logger

  @doc """
  Normalizes product data from any source (mock, real, AI crawler) to Flutter-compatible format.

  Returns normalized product data map
  """
  def normalize_product_data(product_data, source \\ :unknown) do
    Logger.debug("Normalizing product data from #{source}: #{inspect(product_data)}")

    product_data
    |> ensure_required_fields()
    |> normalize_field_names()
    |> normalize_dimensions()
    |> normalize_images()
    |> add_metadata(source)
    |> validate_final_structure()
  end

  @doc """
  Converts database product to Flutter-compatible format.

  Returns Flutter-compatible product map
  """
  def database_to_flutter_format(%RealProductSizeBackend.Products.Product{} = product) do
    %{
      id: product.id,
      name: product.title,
      imageUrls: normalize_image_list(product.image_urls, product.primary_image_url),
      dimensions: format_dimensions_string(product),
      dimensionsStructured: build_structured_dimensions(product),
      selectedImageIndices: [0],
      displayedImageIndex: 0,
      # Additional backend fields
      external_id: product.external_id,
      source_url: product.source_url,
      source_type: product.source_type,
      brand: product.brand,
      category: product.category,
      subcategory: product.subcategory,
      price_usd: product.price_usd,
      currency: product.currency,
      description: product.description,
      features: normalize_list(product.features),
      materials: normalize_list(product.materials),
      colors: normalize_list(product.colors),
      crawled_at: product.crawled_at,
      crawl_quality_score: product.crawl_quality_score,
      ar_model_url: product.ar_model_url,
      model_generation_status: product.model_generation_status || "none",
      model_generated_at: product.model_generated_at
    }
  end

  @doc """
  Converts mock product data to Flutter-compatible format.

  Returns Flutter-compatible product map
  """
  def mock_to_flutter_format(mock_data) do
    mock_data
    |> ensure_required_fields()
    |> normalize_field_names()
    |> normalize_dimensions()
    |> normalize_images()
    |> add_metadata(:mock)
  end

  @doc """
  Converts real crawler data to Flutter-compatible format.

  Returns Flutter-compatible product map
  """
  def crawler_to_flutter_format(crawler_data) do
    crawler_data
    |> ensure_required_fields()
    |> normalize_field_names()
    |> normalize_dimensions()
    |> normalize_images()
    |> add_metadata(:crawler)
  end

  # Private functions

  defp ensure_required_fields(data) do
    # Ensure all required fields exist with sensible defaults
    data
    |> Map.put_new(:id, generate_id())
    |> Map.put_new(:name, Map.get(data, :title) || "Unknown Product")
    |> Map.put_new(:title, Map.get(data, :name) || "Unknown Product")
    |> Map.put_new(:imageUrls, [])
    |> Map.put_new(:dimensions, "Dimensions not available")
    |> Map.put_new(:dimensionsStructured, %{length: 0.0, width: 0.0, height: 0.0, unit: "mm"})
    |> Map.put_new(:selectedImageIndices, [0])
    |> Map.put_new(:displayedImageIndex, 0)
    |> Map.put_new(:external_id, "")
    |> Map.put_new(:source_url, "")
    |> Map.put_new(:source_type, "unknown")
    |> Map.put_new(:brand, "Unknown")
    |> Map.put_new(:category, "General")
    |> Map.put_new(:subcategory, "General")
    |> Map.put_new(:price_usd, 0.0)
    |> Map.put_new(:currency, "USD")
    |> Map.put_new(:description, "")
    |> Map.put_new(:features, [])
    |> Map.put_new(:materials, [])
    |> Map.put_new(:colors, [])
    |> Map.put_new(:crawled_at, DateTime.utc_now())
    |> Map.put_new(:crawl_quality_score, 0.0)
    |> Map.put_new(:ar_model_url, nil)
    |> Map.put_new(:model_generation_status, "none")
    |> Map.put_new(:model_generated_at, nil)
  end

  defp normalize_field_names(data) do
    # Ensure consistent field naming
    data
    |> Map.put(:name, Map.get(data, :title) || Map.get(data, :name))
    |> Map.put(:title, Map.get(data, :title) || Map.get(data, :name))
    |> Map.put(:imageUrls, Map.get(data, :imageUrls) || Map.get(data, :image_urls) || [])
    |> Map.put(:dimensionsStructured, Map.get(data, :dimensionsStructured) || Map.get(data, :dimensions_structured) || %{})
  end

  defp normalize_dimensions(data) do
    # Ensure dimensions are properly formatted
    dimensions_structured = build_structured_dimensions(data)
    dimensions_string = format_dimensions_string(data, dimensions_structured)

    data
    |> Map.put(:dimensionsStructured, dimensions_structured)
    |> Map.put(:dimensions, dimensions_string)
  end

  defp normalize_images(data) do
    # Ensure imageUrls is a proper list
    image_urls = normalize_image_list(
      Map.get(data, :imageUrls) || Map.get(data, :image_urls) || [],
      Map.get(data, :primary_image_url)
    )

    data
    |> Map.put(:imageUrls, image_urls)
    |> Map.put(:selectedImageIndices, [0])
    |> Map.put(:displayedImageIndex, 0)
  end

  defp add_metadata(data, source) do
    data
    |> Map.put(:data_source, source)
    |> Map.put(:normalized_at, DateTime.utc_now())
  end

  defp validate_final_structure(data) do
    # Validate that all required fields are present and properly formatted
    required_fields = [
      :id, :name, :imageUrls, :dimensions, :dimensionsStructured,
      :selectedImageIndices, :displayedImageIndex
    ]

    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(data, &1)))

    if length(missing_fields) > 0 do
      Logger.warning("Missing required fields in normalized data: #{inspect(missing_fields)}")
    end

    data
  end

  defp build_structured_dimensions(data) do
    # Try to get structured dimensions from various possible sources
    case Map.get(data, :dimensionsStructured) do
      nil ->
        # Try to build from individual dimension fields
        length = get_dimension_value(data, :length_mm, :length)
        width = get_dimension_value(data, :width_mm, :width)
        height = get_dimension_value(data, :height_mm, :height)

        %{
          length: length,
          width: width,
          height: height,
          unit: "mm"
        }

      structured when is_map(structured) ->
        # Ensure unit is present
        Map.put_new(structured, :unit, "mm")

      _ ->
        # Fallback to default
        %{length: 0.0, width: 0.0, height: 0.0, unit: "mm"}
    end
  end

  defp get_dimension_value(data, field1, field2) do
    case {Map.get(data, field1), Map.get(data, field2)} do
      {nil, nil} -> 0.0
      {value, _} when not is_nil(value) -> ensure_float(value)
      {_, value} when not is_nil(value) -> ensure_float(value)
      _ -> 0.0
    end
  end

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

  defp format_dimensions_string(data, dimensions_structured \\ nil) do
    dimensions = dimensions_structured || build_structured_dimensions(data)

    case {dimensions.length, dimensions.width, dimensions.height} do
      {l, w, h} when l > 0 and w > 0 and h > 0 ->
        "#{l}mm × #{w}mm × #{h}mm"

      _ ->
        "Dimensions not available"
    end
  end

  defp normalize_image_list(image_urls, primary_image_url) do
    Logger.debug("Normalizing image list - image_urls: #{inspect(image_urls)}, primary: #{inspect(primary_image_url)}")

    # Ensure imageUrls is a list of strings
    images = case image_urls do
      nil ->
        Logger.debug("image_urls is nil, using empty list")
        []
      urls when is_list(urls) ->
        Logger.debug("image_urls is list with #{length(urls)} items: #{inspect(urls)}")
        urls
      _ ->
        Logger.debug("image_urls is not a list: #{inspect(image_urls)}")
        []
    end

    # Add primary image if not already in the list
    final_images = case primary_image_url do
      nil ->
        Logger.debug("primary_image_url is nil, using images as-is")
        images
      url when is_binary(url) and url != "" ->
        Logger.debug("Adding primary image URL: #{url}")
        if url in images, do: images, else: [url | images]
      _ ->
        Logger.debug("primary_image_url is invalid: #{inspect(primary_image_url)}")
        images
    end

    filtered_images = final_images
    |> Enum.filter(&(is_binary(&1) and &1 != ""))

    result = case filtered_images do
      [] ->
        Logger.debug("No valid images found, using placeholder")
        ["https://via.placeholder.com/300x300/CCCCCC/FFFFFF?text=No+Image"]
      imgs ->
        Logger.debug("Using #{length(imgs)} valid images: #{inspect(imgs)}")
        imgs
    end

    Logger.debug("Final normalized image list: #{inspect(result)}")
    result
  end

  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(_), do: []

  defp generate_id do
    "prod_#{:rand.uniform(1000000)}"
  end

  @doc """
  Test function for development.
  """
  def test_normalization do
    # Test mock data normalization
    mock_data = %{
      id: "mock-1",
      title: "Test Product",
      image_urls: ["https://example.com/image1.jpg"],
      length_mm: 100.0,
      width_mm: 50.0,
      height_mm: 25.0
    }

    normalized = normalize_product_data(mock_data, :mock)
    Logger.info("Normalized mock data: #{inspect(normalized)}")

    # Test real data normalization
    real_data = %{
      name: "Real Product",
      imageUrls: ["https://example.com/real.jpg"],
      dimensionsStructured: %{length: 200.0, width: 100.0, height: 50.0, unit: "mm"}
    }

    normalized_real = normalize_product_data(real_data, :real)
    Logger.info("Normalized real data: #{inspect(normalized_real)}")

    :ok
  end
end
