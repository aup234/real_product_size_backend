defmodule RealProductSizeBackend.AiCrawler.PromptEngine do
  @moduledoc """
  Prompt engineering system for AI crawler.

  Builds structured, optimized prompts for extracting product information
  from Amazon HTML content using AI models.
  """

  @doc """
  Builds a comprehensive prompt for product data extraction.

  ## Examples

      iex> PromptEngine.build_product_extraction_prompt(%{title: "Product", price: "$19.99", ...}, "https://amazon.com/dp/123")
      "You are an expert at extracting product information..."
  """
  def build_product_extraction_prompt(extracted_data, url) do
    # Build focused content summary using the new focused extractor
    content_summary = RealProductSizeBackend.AiCrawler.FocusedContentExtractor.build_focused_content_summary(extracted_data)

    """
    You are an expert at extracting product information from e-commerce product pages.
    The product page is: #{url}

    Here is the extracted content from the page:

    #{content_summary}

    CRITICAL: Return ONLY a valid JSON object. No explanations, no additional text, no markdown formatting.

    Extract the following information and return it as a valid JSON object:

    {
      "title": "Product title (string)",
      "dimensions": {
        "length": 100.0,
        "width": 50.0,
        "height": 25.0,
        "unit": "mm"
      },
      "images": ["image_url_1", "image_url_2"],
      "url": "#{url}"
    }

    IMPORTANT RULES:
    1. Return ONLY the JSON object - no other text
    2. If information is not available, use null for that field
    3. For dimensions, look in the dimension sections provided above
    4. For images, use the image URLs provided above
    5. Ensure all strings are properly quoted
    6. Ensure all numbers are properly formatted (no quotes around numbers)
    7. Convert all dimensions to millimeters (mm)
    8. Extract actual product images, not logos or promotional banners
    """
  end


  @doc """
  Builds a focused prompt for dimension extraction only.
  """
  def build_dimension_extraction_prompt(html_content) do
    """
    You are an expert at extracting product dimensions from Amazon product pages.

    Extract ONLY the product dimensions from this HTML content and return a JSON object:

    {
      "dimensions": {
        "length": 100.0,
        "width": 50.0,
        "height": 25.0,
        "unit": "mm"
      },
      "confidence": 0.95,
      "source": "product_details_table"
    }

    INSTRUCTIONS:
    1. Convert all units to millimeters (mm)
    2. Look for dimensions in: product details table, specifications, description, or feature bullets
    3. If no dimensions found, return null for all dimension values
    4. Return confidence score (0.0 to 1.0) based on how certain you are
    5. Indicate the source where you found the dimensions

    HTML Content:
    #{html_content}
    """
  end

  @doc """
  Builds a prompt for price extraction only.
  """
  def build_price_extraction_prompt(html_content) do
    """
    You are an expert at extracting product prices from Amazon product pages.

    Extract ONLY the main product price from this HTML content and return a JSON object:

    {
      "price": "¥1,234",
      "currency": "JPY",
      "original_price": "¥1,500",
      "discount_percentage": 18,
      "confidence": 0.95
    }

    INSTRUCTIONS:
    1. Extract the main product price, not shipping or additional costs
    2. Include currency symbol or code
    3. If there's a discount, include original price and discount percentage
    4. If no price found, return null for price field
    5. Return confidence score (0.0 to 1.0)

    HTML Content:
    #{html_content}
    """
  end

  @doc """
  Builds a prompt for image extraction only.
  """
  def build_image_extraction_prompt(html_content) do
    """
    You are an expert at extracting product images from Amazon product pages.

    Extract ONLY the product image URLs from this HTML content and return a JSON object:

    {
      "images": [
        "https://m.media-amazon.com/images/I/image1.jpg",
        "https://m.media-amazon.com/images/I/image2.jpg"
      ],
      "main_image": "https://m.media-amazon.com/images/I/main_image.jpg",
      "count": 5
    }

    INSTRUCTIONS:
    1. Extract actual product images, not logos or promotional banners
    2. Include the main product image separately
    3. Return full URLs, not relative paths
    4. Exclude placeholder or broken image URLs
    5. Limit to maximum 10 images

    HTML Content:
    #{html_content}
    """
  end

  @doc """
  Builds a prompt for basic product information extraction.
  """
  def build_basic_info_prompt(html_content) do
    """
    You are an expert at extracting basic product information from Amazon product pages.

    Extract ONLY the basic product information from this HTML content and return a JSON object:

    {
      "title": "Product title",
      "brand": "Brand name",
      "category": "Product category",
      "availability": "In stock/Out of stock/Pre-order",
      "rating": "4.5 out of 5 stars",
      "review_count": "1,234 reviews"
    }

    INSTRUCTIONS:
    1. Extract the main product title, not promotional text
    2. Find the brand name from product details or title
    3. Determine the product category
    4. Check availability status
    5. Extract rating and review count if available
    6. If information not found, use null

    HTML Content:
    #{html_content}
    """
  end

  @doc """
  Builds a cost-optimized prompt for simple extractions.
  """
  def build_cost_optimized_prompt(html_content, fields \\ [:title, :price, :dimensions]) do
    field_instructions = build_field_instructions(fields)

    """
    Extract ONLY the requested product information from this HTML and return JSON:

    #{field_instructions}

    HTML Content:
    #{html_content}
    """
  end

  defp build_field_instructions(fields) do
    field_map = %{
      title: %{type: "string", description: "Product title"},
      price: %{type: "string", description: "Price with currency"},
      dimensions: %{
        type: "object",
        description: "Dimensions in mm: {length, width, height, unit}"
      },
      brand: %{type: "string", description: "Brand name"},
      rating: %{type: "string", description: "Customer rating"},
      availability: %{type: "string", description: "Stock status"},
      images: %{type: "array", description: "Image URLs"}
    }

    fields
    |> Enum.map(fn field ->
      case Map.get(field_map, field) do
        %{type: type, description: desc} -> "\"#{field}\": #{type} - #{desc}"
        nil -> "\"#{field}\": unknown field"
      end
    end)
    |> Enum.join("\n")
  end

  @doc """
  Builds a validation prompt to check extracted data quality.
  """
  def build_validation_prompt(extracted_data, original_html) do
    """
    You are an expert at validating extracted product data.

    Validate this extracted product data against the original HTML content:

    Extracted Data:
    #{Jason.encode!(extracted_data, pretty: true)}

    Original HTML (first 2000 characters):
    #{String.slice(original_html, 0, 2000)}

    Return a JSON validation result:

    {
      "is_valid": true,
      "confidence": 0.95,
      "issues": ["Issue 1", "Issue 2"],
      "suggestions": ["Suggestion 1", "Suggestion 2"],
      "missing_fields": ["field1", "field2"]
    }

    INSTRUCTIONS:
    1. Check if extracted data matches the HTML content
    2. Identify any obvious errors or inconsistencies
    3. Suggest improvements for data quality
    4. List any important fields that were missed
    5. Provide confidence score (0.0 to 1.0)
    """
  end

  @doc """
  Builds a prompt for handling Japanese Amazon content.
  """
  def build_japanese_optimized_prompt(html_content, url) do
    """
    あなたはAmazon商品ページから商品情報を抽出する専門家です。

    このHTMLコンテンツから以下の情報を抽出し、有効なJSONオブジェクトのみを返してください：

    {
      "title": "商品タイトル",
      "price": "価格（例：¥1,234）",
      "rating": "評価（例：4.5つ星のうち4.0）",
      "description": "商品説明",
      "dimensions": {
        "length": 100.0,
        "width": 50.0,
        "height": 25.0,
        "unit": "mm"
      },
      "brand": "ブランド名",
      "material": "材質情報",
      "images": ["画像URL1", "画像URL2"],
      "availability": "在庫あり/在庫切れ/予約受付中"
    }

    重要な指示：
    1. JSONオブジェクトのみを返し、追加のテキストは含めない
    2. 情報が利用できない場合は、そのフィールドにnullを使用
    3. 寸法はすべてミリメートル（mm）に変換
    4. 価格は実際の価格を抽出し、プロモーションテキストではない
    5. 日本語と英語の両方のコンテンツを処理

    HTMLコンテンツ:
    #{html_content}

    URL: #{url}
    """
  end
end
