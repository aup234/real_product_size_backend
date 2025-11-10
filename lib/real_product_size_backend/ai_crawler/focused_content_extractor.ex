defmodule RealProductSizeBackend.AiCrawler.FocusedContentExtractor do
  @moduledoc """
  Focused content extractor for AI crawler.

  Extracts only essential content (title, dimensions, images) from HTML
  to optimize AI processing and reduce token usage.

  Supports multiple websites through adapter pattern.
  """

  require Logger

  @doc """
  Extracts focused content from HTML for AI processing.

  ## Examples

      iex> FocusedContentExtractor.extract_focused_content(html_content, "https://amazon.com/dp/123")
      %{title: "Product Title", dimension_sections: [...], images: [...]}
  """
  def extract_focused_content(html_content, url) do
    website_type = detect_website_type(url)
    adapter = get_website_adapter(website_type)

    Logger.info("Using #{website_type} adapter for URL: #{url}")

    case Floki.parse_document(html_content) do
      {:ok, document} ->
        %{
          website_type: website_type,
          title: adapter.extract_title(document),
          dimension_sections: adapter.extract_dimension_sections(document),
          images: adapter.extract_images(document),
          product_context: adapter.extract_product_context(document),
          url: url
        }

      {:error, error} ->
        Logger.error("Failed to parse HTML: #{inspect(error)}")
        %{error: "Failed to parse HTML", url: url}
    end
  end

  @doc """
  Detects the website type from URL.
  """
  def detect_website_type(url) do
    cond do
      String.contains?(url, "amazon.") -> :amazon
      String.contains?(url, "ikea.") -> :ikea
      String.contains?(url, "walmart.") -> :walmart
      String.contains?(url, "target.") -> :target
      String.contains?(url, "bestbuy.") -> :bestbuy
      String.contains?(url, "homedepot.") -> :homedepot
      String.contains?(url, "lowes.") -> :lowes
      String.contains?(url, "wayfair.") -> :wayfair
      String.contains?(url, "overstock.") -> :overstock
      String.contains?(url, "muji.") -> :muji
      String.contains?(url, "onlineshop.muji.com") -> :muji
      true -> :generic
    end
  end

  @doc """
  Gets the appropriate website adapter.
  """
  def get_website_adapter(website_type) do
    case website_type do
      :amazon -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.AmazonAdapter
      :ikea -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.IkeaAdapter
      :walmart -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.WalmartAdapter
      :target -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.TargetAdapter
      :bestbuy -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.BestBuyAdapter
      :homedepot -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.HomeDepotAdapter
      :lowes -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.LowesAdapter
      :wayfair -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.WayfairAdapter
      :overstock -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.OverstockAdapter
      :muji -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.MujiAdapter
      :generic -> RealProductSizeBackend.AiCrawler.WebsiteAdapters.GenericAdapter
    end
  end

  @doc """
  Builds a focused content summary for AI processing.
  """
  def build_focused_content_summary(data) do
    parts = []

    # Title (always include if available)
    parts = if data.title && data.title != "" do
      parts ++ ["TITLE: #{data.title}"]
    else
      parts
    end

    # Dimension sections (prioritized)
    parts = if data.dimension_sections && length(data.dimension_sections) > 0 do
      dimension_text = data.dimension_sections
      |> Enum.map(fn section -> "#{section.type}: #{section.content}" end)
      |> Enum.join("\n")

      parts ++ ["DIMENSION SECTIONS:\n#{dimension_text}"]
    else
      parts
    end

    # Images (limit to first 3)
    parts = if data.images && length(data.images) > 0 do
      image_list = data.images
      |> Enum.take(3)
      |> Enum.join(", ")

      parts ++ ["PRODUCT IMAGES: #{image_list}"]
    else
      parts
    end

    # Product context (brief)
    parts = if data.product_context && data.product_context != "" do
      context_preview = String.slice(data.product_context, 0, 500)
      parts ++ ["PRODUCT CONTEXT: #{context_preview}..."]
    else
      parts
    end

    if parts == [], do: "No product data extracted", else: Enum.join(parts, "\n\n")
  end

  @doc """
  Validates if an image URL is a valid product image.
  """
  def is_valid_product_image(src) when is_binary(src) do
    # Filter out non-product images
    invalid_patterns = [
      "logo", "icon", "banner", "advertisement", "sponsor",
      "social", "share", "facebook", "twitter", "instagram",
      "pixel", "tracking", "analytics", "cookie"
    ]

    src &&
    String.length(src) > 10 &&
    !Enum.any?(invalid_patterns, fn pattern ->
      String.contains?(String.downcase(src), pattern)
    end)
  end

  def is_valid_product_image(_), do: false
end
