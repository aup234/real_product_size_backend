defmodule RealProductSizeBackend.MockDataService do
  @moduledoc """
  Mock data service for demo purposes.
  """

  @mock_products [
    %{
      id: "mock-1",
      external_id: "B0F37TH3M3",
      source_url: "https://www.amazon.co.jp/dp/B0F37TH3M3",
      source_type: "amazon",
      title: "Mock Amazon Product - Wireless Headphones",
      brand: "MockBrand",
      category: "Electronics",
      subcategory: "Audio",
      length_mm: 180.0,
      width_mm: 80.0,
      height_mm: 25.0,
      weight_g: 250.0,
      dimensions_verified: true,
      price_usd: 99.99,
      currency: "USD",
      description: "High-quality wireless headphones with noise cancellation",
      features: ["Bluetooth 5.0", "Noise Cancellation", "40h Battery"],
      materials: ["Plastic", "Metal"],
      colors: ["Black", "White"],
      primary_image_url:
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
      image_urls: [
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/henry-be-IicyiaPYGGI-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/luca-bravo-ESkw2ayO2As-unsplash.jpg"
      ],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: 0.95
    },
    %{
      id: "mock-2",
      external_id: "B0F37TH3M4",
      source_url: "https://www.amazon.co.jp/dp/B0F37TH3M4",
      source_type: "amazon",
      title: "Mock Amazon Product - Laptop Stand",
      brand: "MockBrand",
      category: "Electronics",
      subcategory: "Accessories",
      length_mm: 250.0,
      width_mm: 200.0,
      height_mm: 50.0,
      weight_g: 800.0,
      dimensions_verified: true,
      price_usd: 49.99,
      currency: "USD",
      description: "Adjustable aluminum laptop stand for ergonomic positioning",
      features: ["Adjustable Height", "Aluminum Construction", "Non-slip Base"],
      materials: ["Aluminum", "Rubber"],
      colors: ["Silver", "Black"],
      primary_image_url:
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/henry-be-IicyiaPYGGI-unsplash.jpg",
      image_urls: [
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/henry-be-IicyiaPYGGI-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
      ],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: 0.92
    },
    %{
      id: "mock-3",
      external_id: "B0F37TH3M5",
      source_url: "https://www.amazon.co.jp/dp/B0F37TH3M5",
      source_type: "amazon",
      title: "Mock Amazon Product - Coffee Maker",
      brand: "MockBrand",
      category: "Home & Kitchen",
      subcategory: "Coffee & Tea",
      length_mm: 300.0,
      width_mm: 250.0,
      height_mm: 400.0,
      weight_g: 2500.0,
      dimensions_verified: true,
      price_usd: 199.99,
      currency: "USD",
      description: "Professional coffee maker with programmable features",
      features: ["Programmable", "12-cup Capacity", "Auto-shutoff"],
      materials: ["Stainless Steel", "Plastic"],
      colors: ["Stainless Steel", "Black"],
      primary_image_url:
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/luca-bravo-ESkw2ayO2As-unsplash.jpg",
      image_urls: [
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/luca-bravo-ESkw2ayO2As-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/henry-be-IicyiaPYGGI-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg"
      ],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: 0.88
    },
    %{
      id: "mock-4",
      external_id: "B0F37TH3M6",
      source_url: "https://www.amazon.co.jp/dp/B0F37TH3M6",
      source_type: "amazon",
      title: "Mock Gaming Chair - Ergonomic Office Chair",
      brand: "MockBrand",
      category: "Home & Kitchen",
      subcategory: "Furniture",
      length_mm: 650.0,
      width_mm: 650.0,
      height_mm: 1200.0,
      weight_g: 15000.0,
      dimensions_verified: true,
      price_usd: 299.99,
      currency: "USD",
      description: "Ergonomic gaming chair with lumbar support and adjustable armrests",
      features: ["Lumbar Support", "Adjustable Armrests", "Reclining", "360° Swivel"],
      materials: ["PU Leather", "Metal", "Foam"],
      colors: ["Black", "Red", "Blue"],
      primary_image_url:
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg",
      image_urls: [
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/henry-be-IicyiaPYGGI-unsplash.jpg"
      ],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: 0.90
    }
  ]

  @doc """
  Lists mock products with optional filtering.
  """
  def list_mock_products(params \\ %{}) do
    products = @mock_products

    # Apply filters if provided
    products =
      if Map.has_key?(params, "category") do
        Enum.filter(products, &(&1.category == params["category"]))
      else
        products
      end

    products =
      if Map.has_key?(params, "brand") do
        Enum.filter(products, &(&1.brand == params["brand"]))
      else
        products
      end

    # Apply pagination if provided
    page =
      case Map.get(params, "page") do
        nil -> 1
        page_str when is_binary(page_str) -> String.to_integer(page_str)
        page_int when is_integer(page_int) -> page_int
      end

    per_page =
      case Map.get(params, "per_page") do
        nil -> 10
        per_page_str when is_binary(per_page_str) -> String.to_integer(per_page_str)
        per_page_int when is_integer(per_page_int) -> per_page_int
      end

    start_index = (page - 1) * per_page
    _end_index = start_index + per_page

    Enum.slice(products, start_index, per_page)
  end

  @doc """
  Gets a single mock product by ID.
  """
  def get_mock_product(id) do
    Enum.find(@mock_products, &(&1.id == id))
  end

  @doc """
  Creates a mock product from a crawled URL.
  """
  def create_mock_product_from_url(url) do
    # Simulate product creation from URL
    %{
      id: "mock-#{:rand.uniform(1000)}",
      external_id: "B0F37TH3M#{:rand.uniform(1000)}",
      source_url: url,
      source_type: "amazon",
      title: "Mock Product from #{url}",
      brand: "MockBrand",
      category: "General",
      subcategory: "Misc",
      length_mm: 100.0 + :rand.uniform(200),
      width_mm: 50.0 + :rand.uniform(150),
      height_mm: 20.0 + :rand.uniform(100),
      weight_g: 100.0 + :rand.uniform(500),
      dimensions_verified: true,
      price_usd: 10.0 + :rand.uniform(200),
      currency: "USD",
      description: "Mock product created from URL crawl",
      features: ["Feature 1", "Feature 2"],
      materials: ["Material 1"],
      colors: ["Color 1"],
      primary_image_url:
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
      image_urls: [
        "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com/steven-kamenar-MMJx78V7xS8-unsplash.jpg"
      ],
      crawled_at: DateTime.utc_now(),
      crawl_quality_score: 0.85
    }
  end

  @doc """
  Generates a mock product from a crawled URL (alias for create_mock_product_from_url).
  Returns Flutter-compatible format.
  """
  def generate_mock_product_from_url(url) do
    product = create_mock_product_from_url(url)

    # Determine product type and generate appropriate images
    product_images = get_product_images_by_url(url)

    # Convert to Flutter-compatible format
    mock_data = %{
      id: product.id,
      name: product.title,
      imageUrls: product_images,
      dimensions: format_dimensions_string(product),
      dimensionsStructured: %{
        length: product.length_mm,
        width: product.width_mm,
        height: product.height_mm,
        unit: "mm"
      },
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
      features: product.features,
      materials: product.materials,
      colors: product.colors,
      crawled_at: product.crawled_at,
      crawl_quality_score: product.crawl_quality_score
    }
    {:ok, mock_data}
  end

  # Get product images based on URL keywords
  defp get_product_images_by_url(url) do
    url_lower = String.downcase(url)

    # S3 base URL for product images
    s3_base_url = "https://testingfile-sharing.s3-ap-southeast-1.amazonaws.com"

    cond do
      String.contains?(url_lower, "headphone") or String.contains?(url_lower, "earphone") ->
        [
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg",
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
        ]

      String.contains?(url_lower, "laptop") or String.contains?(url_lower, "computer") ->
        [
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg",
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
        ]

      String.contains?(url_lower, "coffee") or String.contains?(url_lower, "espresso") ->
        [
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg",
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
        ]

      String.contains?(url_lower, "phone") or String.contains?(url_lower, "smartphone") ->
        [
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg",
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg"
        ]

      String.contains?(url_lower, "book") or String.contains?(url_lower, "novel") ->
        [
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg",
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
        ]

      true ->
        # Default generic product images using S3 images
        [
          "#{s3_base_url}/steven-kamenar-MMJx78V7xS8-unsplash.jpg",
          "#{s3_base_url}/henry-be-IicyiaPYGGI-unsplash.jpg",
          "#{s3_base_url}/luca-bravo-ESkw2ayO2As-unsplash.jpg",
          "#{s3_base_url}/6f5d9ae5-3184-427b-9476-cfb02c73fb9b_.jpg"
        ]
    end
  end

  # Helper function to format dimensions as string
  defp format_dimensions_string(product) do
    "#{product.length_mm}mm × #{product.width_mm}mm × #{product.height_mm}mm"
  end

  @doc """
  Searches mock products by query.
  """
  def search_mock_products(query) do
    @mock_products
    |> Enum.filter(fn product ->
      String.contains?(String.downcase(product.title), String.downcase(query)) or
        String.contains?(String.downcase(product.description), String.downcase(query)) or
        String.contains?(String.downcase(product.brand), String.downcase(query))
    end)
  end

  @doc """
  Gets mock categories.
  """
  def get_mock_categories do
    @mock_products
    |> Enum.map(& &1.category)
    |> Enum.uniq()
  end

  @doc """
  Gets mock brands.
  """
  def get_mock_brands do
    @mock_products
    |> Enum.map(& &1.brand)
    |> Enum.uniq()
  end
end
