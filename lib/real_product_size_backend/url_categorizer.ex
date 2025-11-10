defmodule RealProductSizeBackend.UrlCategorizer do
  @moduledoc """
  Smart URL categorization system for AR suitability, product type detection, and size relevance scoring.

  This module analyzes URLs and product data to determine:
  1. AR Suitability - Whether a product is suitable for AR visualization
  2. Product Type Detection - Categorize products (electronics, furniture, etc.)
  3. Size Relevance Scoring - Prioritize products likely to have dimensions
  """

  require Logger

  @doc """
  Categorizes a URL and product data for AR suitability and processing priority.

  Returns %{ar_suitable: boolean, product_type: atom, size_relevance_score: float, category: map}
  """
  def categorize_url(url, product_data \\ %{}) do
    platform = extract_platform_from_url(url)

    %{
      ar_suitable: is_ar_suitable?(platform, url, product_data),
      product_type: detect_product_type(platform, url, product_data),
      size_relevance_score: calculate_size_relevance_score(platform, url, product_data),
      category: build_category_metadata(platform, url, product_data)
    }
  end

  @doc """
  Checks if a product is suitable for AR visualization.
  """
  def is_ar_suitable?(platform, url, product_data \\ %{}) do
    cond do
      # Digital products are not AR suitable
      is_digital_product?(platform, url, product_data) ->
        false

      # Services are not AR suitable
      is_service_product?(platform, url, product_data) ->
        false

      # Gift cards and vouchers are not AR suitable
      is_gift_card?(platform, url, product_data) ->
        false

      # Books and media are generally not AR suitable
      is_media_product?(platform, url, product_data) ->
        false

      # Physical products with dimensions are AR suitable
      has_dimensions?(product_data) ->
        true

      # Default to true for physical products
      true ->
        true
    end
  end

  @doc """
  Detects the product type based on URL patterns and product data.
  """
  def detect_product_type(platform, url, product_data \\ %{}) do
    # Try URL-based detection first
    url_type = detect_product_type_from_url(platform, url)

    # Try product data-based detection
    data_type = detect_product_type_from_data(product_data)

    # Prefer data-based detection if available, otherwise use URL-based
    data_type || url_type || :general
  end

  @doc """
  Calculates size relevance score (0.0 to 1.0) based on likelihood of having dimensions.
  """
  def calculate_size_relevance_score(platform, url, product_data \\ %{}) do
    # Platform-specific scoring
    platform_score = get_platform_size_relevance(platform)

    # Product type scoring
    type_score = get_product_type_size_relevance(detect_product_type(platform, url, product_data))

    # URL pattern scoring
    url_score = get_url_pattern_size_relevance(platform, url)

    # Product data scoring
    data_score = get_data_size_relevance(product_data)

    # Calculate weighted average
    weighted_score = (platform_score * 0.3) + (type_score * 0.4) + (url_score * 0.2) + (data_score * 0.1)

    # Ensure score is between 0.0 and 1.0
    max(0.0, min(1.0, weighted_score))
  end

  # Private functions

  defp extract_platform_from_url(url) do
    cond do
      String.contains?(url, "amazon.") -> :amazon
      String.contains?(url, "ikea.com") -> :ikea
      String.contains?(url, "walmart.") -> :walmart
      String.contains?(url, "target.") -> :target
      String.contains?(url, "bestbuy.") -> :bestbuy
      true -> :unknown
    end
  end

  # AR Suitability Checks

  defp is_digital_product?(_platform, url, product_data) do
    digital_keywords = [
      "ebook", "e-book", "digital", "download", "software", "app", "game",
      "music", "video", "movie", "tv", "streaming", "subscription"
    ]

    url_contains_digital = Enum.any?(digital_keywords, fn keyword ->
      String.contains?(String.downcase(url), keyword)
    end)

    data_contains_digital = case product_data do
      %{category: category} when is_binary(category) ->
        String.contains?(String.downcase(category), "digital") or
        String.contains?(String.downcase(category), "software")
      _ -> false
    end

    url_contains_digital or data_contains_digital
  end

  defp is_service_product?(_platform, url, _product_data) do
    service_keywords = [
      "service", "repair", "installation", "consultation", "support",
      "maintenance", "cleaning", "delivery", "shipping"
    ]

    Enum.any?(service_keywords, fn keyword ->
      String.contains?(String.downcase(url), keyword)
    end)
  end

  defp is_gift_card?(_platform, url, _product_data) do
    gift_keywords = [
      "gift card", "giftcard", "voucher", "coupon", "credit"
    ]

    Enum.any?(gift_keywords, fn keyword ->
      String.contains?(String.downcase(url), keyword)
    end)
  end

  defp is_media_product?(_platform, url, _product_data) do
    media_keywords = [
      "book", "magazine", "newspaper", "cd", "dvd", "blu-ray",
      "vinyl", "cassette", "tape"
    ]

    Enum.any?(media_keywords, fn keyword ->
      String.contains?(String.downcase(url), keyword)
    end)
  end

  defp has_dimensions?(product_data) do
    case product_data do
      %{dimensionsStructured: %{length: l, width: w, height: h}} ->
        l > 0 and w > 0 and h > 0
      _ -> false
    end
  end

  # Product Type Detection

  defp detect_product_type_from_url(_platform, url) do
    url_lower = String.downcase(url)

    cond do
      # Furniture
      String.contains?(url_lower, "furniture") or
      String.contains?(url_lower, "chair") or
      String.contains?(url_lower, "table") or
      String.contains?(url_lower, "sofa") or
      String.contains?(url_lower, "bed") or
      String.contains?(url_lower, "desk") ->
        :furniture

      # Electronics
      String.contains?(url_lower, "electronics") or
      String.contains?(url_lower, "phone") or
      String.contains?(url_lower, "laptop") or
      String.contains?(url_lower, "computer") or
      String.contains?(url_lower, "tv") or
      String.contains?(url_lower, "camera") ->
        :electronics

      # Clothing
      String.contains?(url_lower, "clothing") or
      String.contains?(url_lower, "shirt") or
      String.contains?(url_lower, "pants") or
      String.contains?(url_lower, "dress") or
      String.contains?(url_lower, "shoes") ->
        :clothing

      # Home & Garden
      String.contains?(url_lower, "home") or
      String.contains?(url_lower, "garden") or
      String.contains?(url_lower, "kitchen") or
      String.contains?(url_lower, "bathroom") ->
        :home_garden

      # Sports & Outdoors
      String.contains?(url_lower, "sports") or
      String.contains?(url_lower, "outdoor") or
      String.contains?(url_lower, "fitness") or
      String.contains?(url_lower, "exercise") ->
        :sports_outdoors

      # Toys & Games
      String.contains?(url_lower, "toy") or
      String.contains?(url_lower, "game") or
      String.contains?(url_lower, "puzzle") ->
        :toys_games

      # Automotive
      String.contains?(url_lower, "auto") or
      String.contains?(url_lower, "car") or
      String.contains?(url_lower, "vehicle") ->
        :automotive

      true -> :general
    end
  end

  defp detect_product_type_from_data(product_data) do
    case product_data do
      %{category: category} when is_binary(category) ->
        category_lower = String.downcase(category)

        cond do
          String.contains?(category_lower, "furniture") -> :furniture
          String.contains?(category_lower, "electronics") -> :electronics
          String.contains?(category_lower, "clothing") -> :clothing
          String.contains?(category_lower, "home") -> :home_garden
          String.contains?(category_lower, "sports") -> :sports_outdoors
          String.contains?(category_lower, "toy") -> :toys_games
          String.contains?(category_lower, "auto") -> :automotive
          true -> :general
        end
      _ -> nil
    end
  end

  # Size Relevance Scoring

  defp get_platform_size_relevance(platform) do
    case platform do
      :ikea -> 0.9  # IKEA products almost always have dimensions
      :amazon -> 0.7  # Amazon has good dimension data
      :walmart -> 0.6  # Walmart has decent dimension data
      :target -> 0.6  # Target has decent dimension data
      :bestbuy -> 0.5  # Best Buy has some dimension data
      _ -> 0.3  # Unknown platforms
    end
  end

  defp get_product_type_size_relevance(product_type) do
    case product_type do
      :furniture -> 0.95  # Furniture almost always has dimensions
      :home_garden -> 0.9  # Home items usually have dimensions
      :electronics -> 0.7  # Electronics often have dimensions
      :sports_outdoors -> 0.8  # Sports equipment usually has dimensions
      :toys_games -> 0.6  # Toys sometimes have dimensions
      :clothing -> 0.3  # Clothing rarely has useful dimensions for AR
      :automotive -> 0.8  # Auto parts often have dimensions
      :general -> 0.5  # General products
    end
  end

  defp get_url_pattern_size_relevance(_platform, url) do
    url_lower = String.downcase(url)

    # High relevance patterns
    high_relevance = [
      "furniture", "chair", "table", "sofa", "bed", "desk",
      "cabinet", "shelf", "bookcase", "dresser"
    ]

    if Enum.any?(high_relevance, fn keyword ->
      String.contains?(url_lower, keyword)
    end) do
      0.9
    else
      # Medium relevance patterns
      medium_relevance = [
        "electronics", "appliance", "tool", "equipment"
      ]

      if Enum.any?(medium_relevance, fn keyword ->
        String.contains?(url_lower, keyword)
      end) do
        0.7
      else
        0.5
      end
    end
  end

  defp get_data_size_relevance(product_data) do
    case product_data do
      %{dimensionsStructured: %{length: l, width: w, height: h}} when l > 0 and w > 0 and h > 0 ->
        1.0  # Already has dimensions
      %{dimensions: dimensions} when is_binary(dimensions) and dimensions != "" ->
        0.8  # Has dimension text
      %{materials: materials} when is_list(materials) and length(materials) > 0 ->
        0.6  # Has material info (indicates physical product)
      %{category: category} when is_binary(category) ->
        case String.downcase(category) do
          cat when cat in ["furniture", "home", "electronics"] -> 0.7
          cat when cat in ["clothing", "books", "media"] -> 0.3
          _ -> 0.5
        end
      _ -> 0.3
    end
  end

  defp build_category_metadata(platform, url, product_data) do
    %{
      platform: platform,
      detected_from: detect_source(url, product_data),
      confidence: calculate_detection_confidence(platform, url, product_data),
      keywords: extract_keywords(url, product_data),
      ar_priority: calculate_ar_priority(platform, url, product_data)
    }
  end

  defp detect_source(_url, product_data) do
    cond do
      product_data != %{} -> :product_data
      true -> :url_pattern
    end
  end

  defp calculate_detection_confidence(platform, _url, product_data) do
    base_confidence = 0.5

    # Increase confidence if we have product data
    data_confidence = if product_data != %{}, do: 0.3, else: 0.0

    # Increase confidence for well-known platforms
    platform_confidence = case platform do
      :amazon -> 0.2
      :ikea -> 0.2
      _ -> 0.0
    end

    min(1.0, base_confidence + data_confidence + platform_confidence)
  end

  defp extract_keywords(url, product_data) do
    url_keywords = extract_url_keywords(url)
    data_keywords = extract_data_keywords(product_data)

    (url_keywords ++ data_keywords)
    |> Enum.uniq()
    |> Enum.take(10)  # Limit to top 10 keywords
  end

  defp extract_url_keywords(url) do
    url
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/)
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.take(5)
  end

  defp extract_data_keywords(product_data) do
    case product_data do
      %{title: title} when is_binary(title) ->
        title
        |> String.downcase()
        |> String.split(~r/[^a-z0-9]+/)
        |> Enum.filter(fn word -> String.length(word) > 3 end)
        |> Enum.take(3)
      _ -> []
    end
  end

  defp calculate_ar_priority(platform, url, product_data) do
    base_priority = 0.5

    # High priority for furniture and home items
    type_priority = case detect_product_type(platform, url, product_data) do
      :furniture -> 0.4
      :home_garden -> 0.3
      :electronics -> 0.2
      _ -> 0.0
    end

    # High priority for products with dimensions
    dimension_priority = if has_dimensions?(product_data), do: 0.3, else: 0.0

    min(1.0, base_priority + type_priority + dimension_priority)
  end

  @doc """
  Test function for development.
  """
  def test_categorization do
    test_cases = [
      {"https://www.amazon.com/dp/B0F37TH3M3", %{}},
      {"https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/", %{}},
      {"https://www.amazon.com/dp/B08N5WRWNW", %{category: "Electronics"}},
      {"https://www.amazon.com/dp/B08N5WRWNW", %{category: "Digital Music"}}
    ]

    Enum.each(test_cases, fn {url, product_data} ->
      result = categorize_url(url, product_data)
      Logger.info("URL: #{url}")
      Logger.info("Result: #{inspect(result)}")
      Logger.info("---")
    end)
  end
end
