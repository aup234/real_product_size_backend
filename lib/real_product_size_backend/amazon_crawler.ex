defmodule RealProductSizeBackend.AmazonCrawler do
  @moduledoc """
  Enhanced Amazon product page crawler with demo mode support.
  """

  require Logger
  alias RealProductSizeBackend.MockDataService

  @doc """
  Crawls an Amazon product page and extracts product information.
  Production mode: Real crawling with comprehensive error handling
  """
  def crawl_product(url) do
    # Check if crawler is enabled in production
    production_config = Application.get_env(:real_product_size_backend, :production, [])
    debug_config = Application.get_env(:real_product_size_backend, :debug, [])

    cond do
      # Production mode - use real crawling
      production_config[:enable_crawler] == true ->
        Logger.info("Production crawler enabled - crawling: #{url}")
        crawl_real_amazon_product(url)

      # Debug mode - check if crawler is explicitly disabled
      debug_config[:skip_crawler] == true ->
        Logger.info("Crawler disabled in debug mode - returning mock data for: #{url}")
        {:ok, MockDataService.generate_mock_product_from_url(url)}

      # Default to production crawling
      true ->
        Logger.info("Default to production crawler - crawling: #{url}")
        crawl_real_amazon_product(url)
    end
  end

  # Production: Enhanced real crawling with comprehensive error handling
  defp crawl_real_amazon_product(url) do
    # Get production configuration
    production_config = Application.get_env(:real_product_size_backend, :production, [])
    max_retries = production_config[:max_retries] || 3
    timeout = production_config[:crawl_timeout] || 30_000

    # Use circuit breaker with retry logic
    RealProductSizeBackend.CircuitBreaker.call_with_circuit_breaker(
      :amazon_api,
      fn -> do_amazon_request_with_retry(url, max_retries, timeout) end,
      fn ->
        Logger.error("Amazon API circuit breaker opened - service unavailable")
        {:error, :service_unavailable}
      end
    )
  end

  # Enhanced request with retry logic
  defp do_amazon_request_with_retry(url, max_retries, timeout) do
    do_amazon_request_with_retry(url, max_retries, timeout, 0)
  end

  defp do_amazon_request_with_retry(url, max_retries, timeout, attempt) when attempt < max_retries do
    case do_amazon_request(url, timeout) do
      {:ok, result} -> {:ok, result}
      {:error, reason} when attempt < max_retries - 1 ->
        Logger.warning("Amazon request failed (attempt #{attempt + 1}/#{max_retries}): #{reason}")
        # Exponential backoff
        backoff_time = :math.pow(2, attempt) * 1000 |> round()
        Process.sleep(backoff_time)
        do_amazon_request_with_retry(url, max_retries, timeout, attempt + 1)
      {:error, reason} ->
        Logger.error("Amazon request failed after #{max_retries} attempts: #{reason}")
        {:error, reason}
    end
  end

  defp do_amazon_request_with_retry(_url, max_retries, _timeout, attempt) when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_amazon_request(url, timeout) do
    # Enhanced anti-bot headers for production
    headers = [
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.9,ja;q=0.8"},
      {"Accept-Encoding", "gzip, deflate, br"},
      {"Connection", "keep-alive"},
      {"Upgrade-Insecure-Requests", "1"},
      {"Sec-Fetch-Dest", "document"},
      {"Sec-Fetch-Mode", "navigate"},
      {"Sec-Fetch-Site", "none"},
      {"Cache-Control", "max-age=0"},
      {"DNT", "1"}
    ]

    # Enhanced request options for Req
    request_options = [
      headers: headers,
      redirect: true,
      max_redirects: 5,
      retry: false, # We handle retries manually
      receive_timeout: timeout
    ]

    case Req.get(url, request_options) do
      {:ok, response} when response.status == 200 ->
        Logger.info("Successfully crawled Amazon product: #{url}")
        parse_product_html(response.body, url)

      {:ok, response} when response.status in [301, 302, 303, 307, 308] ->
        Logger.info("Redirect received for #{url}: #{response.status}")
        {:error, "Redirect received: #{response.status}"}

      {:ok, response} when response.status == 404 ->
        Logger.warning("Product not found (404): #{url}")
        {:error, "Product not found"}

      {:ok, response} when response.status == 403 ->
        Logger.warning("Access forbidden (403): #{url}")
        {:error, "Access forbidden - possible rate limiting"}

      {:ok, response} when response.status == 429 ->
        Logger.warning("Rate limited (429): #{url}")
        {:error, "Rate limited"}

      {:ok, response} ->
        Logger.warning("HTTP request failed with status: #{response.status} for #{url}")
        {:error, "HTTP request failed with status: #{response.status}"}

      {:error, :timeout} ->
        Logger.warning("Request timeout for #{url}")
        {:error, "Request timeout"}

      {:error, :nxdomain} ->
        Logger.warning("Domain not found for #{url}")
        {:error, "Domain not found"}

      {:error, reason} ->
        Logger.warning("HTTP request failed for #{url}: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses the product page HTML and extracts relevant information.
  """
  def parse_product_html(html, url) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        # Extract basic product information
        title = extract_title(document)
        dimensions = extract_dimensions(document)

        # Convert dimensions to structured format
        dimensions_structured =
          case dimensions do
            %{length_mm: l, width_mm: w, height_mm: h, unit: unit} ->
              %{
                length: l,
                width: w,
                height: h,
                unit: unit
              }

            _ ->
              %{
                length: 0.0,
                width: 0.0,
                height: 0.0,
                unit: "mm"
              }
          end

        # Format dimensions as string
        dimensions_string =
          case dimensions do
            %{length_mm: l, width_mm: w, height_mm: h, unit: unit} ->
              "#{l}#{unit} × #{w}#{unit} × #{h}#{unit}"

            _ ->
              "Dimensions not available"
          end

        # Return Flutter-compatible format
        product_data = %{
          id: "crawled-#{:rand.uniform(10000)}",
          name: title,
          imageUrls: extract_image_urls(document),
          dimensions: dimensions_string,
          dimensionsStructured: dimensions_structured,
          selectedImageIndices: [0],
          displayedImageIndex: 0,
          # Additional fields for backend processing
          title: title,
          source_url: url,
          price: extract_price(document),
          rating: extract_rating(document),
          description: extract_description(document),
          brand: extract_brand(document),
          material: extract_material(document),
          scraped_at: DateTime.utc_now()
        }

        # Validate that this is actually a product page
        if String.trim(product_data.name) == "" or product_data.name == nil do
          {:error, "Not a product page - no title found"}
        else
          # Log the extracted data
          if Application.get_env(:real_product_size_backend, :debug)[:log_crawling_details] do
            Logger.info("Extracted Product Data: #{inspect(product_data)}")
          end

          # Return the data
          {:ok, product_data}
        end

      {:error, reason} ->
        Logger.error("Failed to parse HTML: #{reason}")
        {:error, "Failed to parse HTML: #{reason}"}
    end
  end

  # Demo: Basic extraction functions
  def extract_title(document) do
    document
    |> Floki.find("#productTitle")
    |> Floki.text()
    |> String.trim()
  end

  # Enhanced price extraction
  defp extract_price(document) do
    # Try multiple price selectors
    price_selectors = [
      ".a-price-whole",
      ".a-price .a-offscreen",
      ".a-price .a-price-whole"
    ]

    Enum.find_value(price_selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [first_element | _rest] ->
          # Take only the first element to avoid concatenation
          Floki.text([first_element])
          |> String.trim()
          |> String.replace(~r/[^\d.]/, "")
          |> case do
            "" -> nil
            price -> price
          end

        elements ->
          # Fallback: take first element if multiple
          [first | _] = elements
          Floki.text([first])
          |> String.trim()
          |> String.replace(~r/[^\d.]/, "")
          |> case do
            "" -> nil
            price -> price
          end
      end
    end)
  end

  defp extract_rating(document) do
    rating_elements = Floki.find(document, ".a-icon-alt")

    case rating_elements do
      [] ->
        nil

      elements ->
        # Find the first element that contains rating information
        Enum.find_value(elements, fn element ->
          text = Floki.text(element)

          if String.contains?(text, "out of 5") or String.contains?(text, "星"),
            do: text,
            else: nil
        end)
    end
  end

  def extract_description(document) do
    description_elements = Floki.find(document, "#feature-bullets .a-list-item")

    case description_elements do
      [] ->
        nil

      elements ->
        elements
        |> Enum.map(&Floki.text/1)
        |> Enum.join(" ")
        |> String.trim()
    end
  end

  def extract_dimensions(document) do
    # Try multiple extraction strategies with fallbacks
    extract_dimensions_crawler(document)
    |> case do
      nil ->
        # Fallback to AI extraction if crawler fails
        Logger.info("Crawler dimension extraction failed, attempting AI extraction")
        extract_dimensions_ai(document)

      dimensions ->
        Logger.info("Successfully extracted dimensions via crawler: #{inspect(dimensions)}")
        dimensions
    end
  end

  @doc """
  Extracts dimensions using traditional crawling methods.
  Tries multiple selectors and parsing strategies.
  """
  def extract_dimensions_crawler(document) do
    # Strategy 1: Product details table
    dimensions = extract_from_product_details_table(document)

    # Strategy 2: Feature bullets
    dimensions = dimensions || extract_from_feature_bullets(document)

    # Strategy 3: Product description
    dimensions = dimensions || extract_from_description(document)

    # Strategy 4: Technical details section
    dimensions = dimensions || extract_from_technical_details(document)

    # Strategy 5: Customer questions/answers
    dimensions = dimensions || extract_from_customer_qa(document)

    dimensions
  end

  @doc """
  Extracts dimensions using AI API (Gemini or Grok).
  Falls back to crawler if AI fails.
  """
  def extract_dimensions_ai(document) do
    # Use the dedicated AI service
    alias RealProductSizeBackend.AiDimensionService

    case AiDimensionService.call_ai_dimension_extraction(document) do
      {:ok, ai_response} ->
        # Parse the AI response
        case AiDimensionService.parse_ai_dimension_response(ai_response) do
          {:ok, dimensions} ->
            dimensions

          {:error, reason} ->
            Logger.warning("Failed to parse AI response: #{reason}")
            nil
        end

      {:error, reason} ->
        Logger.warning("AI dimension extraction failed: #{reason}")
        nil
    end
  end

  # Strategy 1: Product details table
  defp extract_from_product_details_table(document) do
    # Look for dimensions in the product details table
    document
    |> Floki.find("table tr")
    |> Enum.find(fn row ->
      text = Floki.text(row)

      String.contains?(text, "Dimensions") or String.contains?(text, "Size") or
        String.contains?(text, "サイズ") or String.contains?(text, "寸法") or
        String.contains?(text, "Package Dimensions") or
        String.contains?(text, "Product Dimensions")
    end)
    |> case do
      nil ->
        nil

      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
        |> parse_dimensions_text()
    end
  end

  # Strategy 2: Feature bullets
  defp extract_from_feature_bullets(document) do
    document
    |> Floki.find("#feature-bullets .a-list-item")
    |> Enum.find(fn bullet ->
      text = Floki.text(bullet)

      String.contains?(text, "dimension") or String.contains?(text, "size") or
        String.contains?(text, "measurement") or String.contains?(text, "length") or
        String.contains?(text, "width") or String.contains?(text, "height")
    end)
    |> case do
      nil ->
        nil

      bullet ->
        bullet
        |> Floki.text()
        |> String.trim()
        |> parse_dimensions_text()
    end
  end

  # Strategy 3: Product description
  defp extract_from_description(document) do
    description =
      Floki.find(document, "#productDescription p")
      |> Enum.map(&Floki.text/1)
      |> Enum.join(" ")
      |> String.trim()

    # Look for dimension patterns in description
    extract_dimensions_from_text(description)
  end

  # Strategy 4: Technical details section
  defp extract_from_technical_details(document) do
    # Look for technical details section
    document
    |> Floki.find("div")
    |> Enum.find(fn div ->
      text = Floki.text(div)

      String.contains?(text, "Technical Details") or String.contains?(text, "Specifications") or
        String.contains?(text, "Product Specifications")
    end)
    |> case do
      nil ->
        nil

      tech_div ->
        tech_div
        |> Floki.text()
        |> extract_dimensions_from_text()
    end
  end

  # Strategy 5: Customer questions/answers
  defp extract_from_customer_qa(document) do
    # Look for customer Q&A section
    document
    |> Floki.find("div")
    |> Enum.find(fn div ->
      text = Floki.text(div)
      String.contains?(text, "Customer Questions") or String.contains?(text, "Q&A")
    end)
    |> case do
      nil ->
        nil

      qa_div ->
        qa_div
        |> Floki.text()
        |> extract_dimensions_from_text()
    end
  end

  @doc """
  Parses dimension text and converts to standardized format.
  Handles various formats: "10.2 x 5.1 x 2.3 inches", "25.9 x 13 x 6.1 cm", etc.
  """
  def parse_dimensions_text(text) when is_binary(text) do
    # Multiple regex patterns for different dimension formats
    patterns = [
      # Format: "L x W x H" with units
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*(cm|mm|in|inch|inches)/i,

      # Format: "Length: X, Width: Y, Height: Z"
      ~r/length[:\s]+(\d+(?:\.\d+)?)[^\d]*width[:\s]+(\d+(?:\.\d+)?)[^\d]*height[:\s]+(\d+(?:\.\d+)?)/i,

      # Format: "X cm x Y cm x Z cm"
      ~r/(\d+(?:\.\d+)?)\s*cm\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm/i,

      # Format: "X inches x Y inches x Z inches"
      ~r/(\d+(?:\.\d+)?)\s*in(?:ches)?\s*[x×]\s*(\d+(?:\.\d+)?)\s*in(?:ches)?\s*[x×]\s*(\d+(?:\.\d+)?)\s*in(?:ches)?/i,

      # Format: "X mm x Y mm x Z mm"
      ~r/(\d+(?:\.\d+)?)\s*mm\s*[x×]\s*(\d+(?:\.\d+)?)\s*mm\s*[x×]\s*(\d+(?:\.\d+)?)\s*mm/i
    ]

    # Try each pattern
    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [_, l, w, h, unit] ->
          %{
            length_mm: convert_to_mm((elem(Float.parse(l), 0)), unit),
            width_mm: convert_to_mm((elem(Float.parse(w), 0)), unit),
            height_mm: convert_to_mm((elem(Float.parse(h), 0)), unit),
            unit: unit,
            confidence: 0.9
          }

        [_, l, w, h] ->
          # Assume cm if no unit specified
          %{
            length_mm: convert_to_mm((elem(Float.parse(l), 0)), "cm"),
            width_mm: convert_to_mm((elem(Float.parse(w), 0)), "cm"),
            height_mm: convert_to_mm((elem(Float.parse(h), 0)), "cm"),
            unit: "cm",
            confidence: 0.7
          }

        _ ->
          nil
      end
    end)
  end

  def parse_dimensions_text(_), do: nil

  @doc """
  Converts dimensions to millimeters.
  """
  def convert_to_mm(value, unit) when is_number(value) do
    case String.downcase(unit) do
      "mm" -> value
      "cm" -> value * 10.0
      "in" -> value * 25.4
      "inch" -> value * 25.4
      "inches" -> value * 25.4
      # Default to cm
      _ -> value * 10.0
    end
  end

  @doc """
  Extracts dimensions from text using pattern matching.
  """
  def extract_dimensions_from_text(text) when is_binary(text) do
    # Look for dimension patterns in text
    parse_dimensions_text(text)
  end

  def extract_dimensions_from_text(_), do: nil

  def extract_brand(document) do
    document
    |> Floki.find("tr")
    |> Enum.find(fn row ->
      Floki.text(row) |> String.contains?("Brand")
    end)
    |> case do
      nil ->
        nil

      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
    end
  end

  defp extract_material(document) do
    document
    |> Floki.find("tr")
    |> Enum.find(fn row ->
      Floki.text(row) |> String.contains?("Material")
    end)
    |> case do
      nil ->
        nil

      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
    end
  end

  @doc """
  Extracts product image URLs from the document.
  """
  def extract_image_urls(document) do
    # Try multiple image selectors
    image_selectors = [
      "#landingImage",
      "#imgTagWrapperId img",
      ".a-dynamic-image",
      "#main-image-container img",
      ".a-button-selected img"
    ]

    images =
      Enum.flat_map(image_selectors, fn selector ->
        document
        |> Floki.find(selector)
        |> Enum.map(fn img ->
          case Floki.attribute(img, "src") do
            [src] when is_binary(src) -> src
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
      end)

    # Remove duplicates and return
    images
    |> Enum.uniq()
    |> case do
      [] -> ["https://via.placeholder.com/300x300/CCCCCC/FFFFFF?text=No+Image"]
      imgs -> imgs
    end
  end

  @doc """
  Test function for development.
  """
  def test_crawl do
    url = "https://www.amazon.co.jp/dp/B0F37TH3M3?ref_=ast_sto_dp"
    crawl_product(url)
  end

  @doc """
  Validates if a URL is a valid Amazon product URL.
  This is now handled by UrlValidator, but kept for backward compatibility.
  """
  def validate_amazon_url(url) do
    alias RealProductSizeBackend.UrlValidator

    case UrlValidator.validate_url(url) do
      {:ok, :amazon, cleaned_url} -> {:ok, cleaned_url}
      {:ok, platform, _} -> {:error, "Expected Amazon URL, got #{platform}"}
      {:error, reason} -> {:error, reason}
    end
  end
end
