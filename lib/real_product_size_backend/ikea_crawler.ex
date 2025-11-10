defmodule RealProductSizeBackend.IkeaCrawler do
  @moduledoc """
  IKEA product page crawler with AI-powered data extraction.

  This module handles crawling and parsing of IKEA product pages,
  extracting product information including dimensions for AR visualization.
  """

  require Logger

  defp parse_number(str) do
    case Float.parse(str) do
      {float_val, _} -> float_val
      :error ->
        case Integer.parse(str) do
          {int_val, _} -> int_val * 1.0
          :error -> 0.0
        end
    end
  end

  @doc """
  Crawls an IKEA product page and extracts product information.
  """
  def crawl_product(url) do
    # Check if crawler is disabled for demo
    if Application.get_env(:real_product_size_backend, :debug)[:skip_crawler] do
      Logger.info("IKEA crawler disabled - returning mock data for: #{url}")
      {:ok, generate_mock_ikea_product(url)}
    else
      crawl_real_ikea_product(url)
    end
  end

  @doc """
  Parses IKEA product page HTML and extracts relevant information.
  """
  def parse_product_html(html, url) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        # Extract basic product information
        title = extract_title(document)
        dimensions = extract_dimensions(document)
        price = extract_price(document)
        description = extract_description(document)
        images = extract_image_urls(document)
        materials = extract_materials(document)
        colors = extract_colors(document)

        # Convert dimensions to structured format
        dimensions_structured = convert_dimensions_to_structured(dimensions)

        # Format dimensions as string
        dimensions_string = format_dimensions_string(dimensions_structured)

        # Return Flutter-compatible format
        product_data = %{
          id: "ikea-#{:rand.uniform(10000)}",
          name: title,
          imageUrls: images,
          dimensions: dimensions_string,
          dimensionsStructured: dimensions_structured,
          selectedImageIndices: [0],
          displayedImageIndex: 0,
          # Additional fields for backend processing
          title: title,
          price: price,
          description: description,
          materials: materials,
          colors: colors,
          url: url,
          scraped_at: DateTime.utc_now(),
          platform: :ikea,
          crawl_quality_score: calculate_quality_score(title, dimensions, images)
        }

        # Log the extracted data
        if Application.get_env(:real_product_size_backend, :debug)[:log_crawling_details] do
          Logger.info("Extracted IKEA Product Data: #{inspect(product_data)}")
        end

        {:ok, product_data}

      {:error, reason} ->
        Logger.error("Failed to parse IKEA HTML: #{reason}")
        {:error, "Failed to parse HTML: #{reason}"}
    end
  end

  # Private functions

  defp crawl_real_ikea_product(url) do
    RealProductSizeBackend.CircuitBreaker.call_with_circuit_breaker(
      :ikea_api,
      fn -> do_ikea_request(url) end,
      fn -> {:error, :service_unavailable} end
    )
  end

  defp do_ikea_request(url) do
    # IKEA-specific headers
    headers = [
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"},
      {"Upgrade-Insecure-Requests", "1"}
    ]

    case Req.get(url, headers: headers, timeout: 30_000) do
      {:ok, response} when response.status == 200 ->
        parse_product_html(response.body, url)

      {:ok, response} ->
        {:error, "HTTP request failed with status: #{response.status}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp extract_title(document) do
    # Try multiple selectors for IKEA product title
    selectors = [
      "h1[data-testid='product-title']",
      ".pip-header-section h1",
      "h1.pip-header-section__title",
      "h1"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] -> nil
        [element | _] -> Floki.text(element) |> String.trim()
      end
    end) || "IKEA Product"
  end

  defp extract_price(document) do
    # Try multiple selectors for IKEA price
    selectors = [
      "[data-testid='price']",
      ".pip-price__integer",
      ".pip-price",
      ".price"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] -> nil
        elements ->
          elements
          |> Enum.find_value(fn element ->
            text = Floki.text(element)
            if String.match?(text, ~r/\$?\d+/) do
              text
            else
              nil
            end
          end)
      end
    end)
  end

  defp extract_description(document) do
    # Try multiple selectors for IKEA product description
    selectors = [
      "[data-testid='product-description']",
      ".pip-product-details__description",
      ".pip-product-details p",
      ".product-description"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] -> nil
        elements ->
          elements
          |> Enum.map(&Floki.text/1)
          |> Enum.join(" ")
          |> String.trim()
      end
    end)
  end

  defp extract_dimensions(document) do
    # IKEA often has dimensions in product details
    # Try multiple extraction strategies
    extract_from_product_details(document)
    |> case do
      nil -> extract_from_specifications(document)
      dimensions -> dimensions
    end
  end

  defp extract_from_product_details(document) do
    # Look for dimensions in product details section
    document
    |> Floki.find("[data-testid='product-details'] tr, .pip-product-details tr")
    |> Enum.find(fn row ->
      text = Floki.text(row)
      String.contains?(String.downcase(text), "dimension") or
      String.contains?(String.downcase(text), "size") or
      String.contains?(String.downcase(text), "measurement")
    end)
    |> case do
      nil -> nil
      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
        |> parse_dimensions_text()
    end
  end

  defp extract_from_specifications(document) do
    # Look for dimensions in specifications
    document
    |> Floki.find(".pip-product-details, .product-specifications")
    |> Enum.find(fn div ->
      text = Floki.text(div)
      String.contains?(String.downcase(text), "dimension") or
      String.contains?(String.downcase(text), "size")
    end)
    |> case do
      nil -> nil
      div ->
        div
        |> Floki.text()
        |> extract_dimensions_from_text()
    end
  end

  defp extract_materials(document) do
    # Extract materials information
    document
    |> Floki.find("[data-testid='product-details'] tr, .pip-product-details tr")
    |> Enum.find(fn row ->
      text = Floki.text(row)
      String.contains?(String.downcase(text), "material")
    end)
    |> case do
      nil -> []
      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
        |> String.split(",")
        |> Enum.map(&String.trim/1)
    end
  end

  defp extract_colors(document) do
    # Extract color information
    document
    |> Floki.find("[data-testid='product-details'] tr, .pip-product-details tr")
    |> Enum.find(fn row ->
      text = Floki.text(row)
      String.contains?(String.downcase(text), "color")
    end)
    |> case do
      nil -> []
      row ->
        row
        |> Floki.find("td")
        |> Enum.at(1)
        |> Floki.text()
        |> String.trim()
        |> String.split(",")
        |> Enum.map(&String.trim/1)
    end
  end

  defp extract_image_urls(document) do
    # Extract product images
    selectors = [
      "[data-testid='product-image'] img",
      ".pip-media img",
      ".product-image img",
      "img[alt*='product']"
    ]

    images =
      Enum.flat_map(selectors, fn selector ->
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
      [] -> ["https://via.placeholder.com/300x300/CCCCCC/FFFFFF?text=IKEA+Product"]
      imgs -> imgs
    end
  end

  defp parse_dimensions_text(text) when is_binary(text) do
    # IKEA dimensions patterns
    patterns = [
      # Format: "Length: X cm, Width: Y cm, Height: Z cm"
      ~r/length[:\s]+(\d+(?:\.\d+)?)\s*cm[^\d]*width[:\s]+(\d+(?:\.\d+)?)\s*cm[^\d]*height[:\s]+(\d+(?:\.\d+)?)\s*cm/i,

      # Format: "X cm x Y cm x Z cm"
      ~r/(\d+(?:\.\d+)?)\s*cm\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm/i,

      # Format: "X x Y x Z cm"
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [_, l, w, h] ->
          %{
            length_mm: parse_number(l) * 10.0,
            width_mm: parse_number(w) * 10.0,
            height_mm: parse_number(h) * 10.0,
            unit: "cm",
            confidence: 0.9
          }
        _ -> nil
      end
    end)
  end

  defp parse_dimensions_text(_), do: nil

  defp extract_dimensions_from_text(text) when is_binary(text) do
    parse_dimensions_text(text)
  end

  defp extract_dimensions_from_text(_), do: nil

  defp convert_dimensions_to_structured(dimensions) do
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
  end

  defp format_dimensions_string(dimensions) do
    case dimensions do
      %{length: l, width: w, height: h, unit: unit} when l > 0 and w > 0 and h > 0 ->
        "#{l}#{unit} × #{w}#{unit} × #{h}#{unit}"
      _ ->
        "Dimensions not available"
    end
  end

  defp calculate_quality_score(title, dimensions, images) do
    score = 0.0
    score = if title && title != "IKEA Product", do: score + 0.3, else: score
    score = if dimensions, do: score + 0.4, else: score
    score = if length(images) > 0, do: score + 0.3, else: score
    score
  end

  defp generate_mock_ikea_product(url) do
    # Generate mock IKEA product data
    product_id = extract_product_id_from_url(url)

    %{
      id: "ikea-mock-#{product_id}",
      name: "IKEA #{String.capitalize(product_id)} Furniture",
      imageUrls: [
        "https://via.placeholder.com/300x300/FF6B6B/FFFFFF?text=IKEA+Product",
        "https://via.placeholder.com/300x300/4ECDC4/FFFFFF?text=IKEA+Product"
      ],
      dimensions: "120 cm × 60 cm × 80 cm",
      dimensionsStructured: %{
        length: 1200.0,
        width: 600.0,
        height: 800.0,
        unit: "mm"
      },
      selectedImageIndices: [0],
      displayedImageIndex: 0,
      title: "IKEA #{String.capitalize(product_id)} Furniture",
      price: "$99.99",
      description: "Modern IKEA furniture perfect for your home. High quality materials and contemporary design.",
      materials: ["Particleboard", "Laminate"],
      colors: ["White", "Black"],
      url: url,
      scraped_at: DateTime.utc_now(),
      platform: :ikea,
      crawl_quality_score: 0.9
    }
  end

  defp extract_product_id_from_url(url) do
    case Regex.run(~r{/p/[^/]+-(\d+)/}, url) do
      [_, product_id] -> product_id
      _ -> "unknown"
    end
  end

  @doc """
  Test function for development.
  """
  def test_crawl do
    url = "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/"
    crawl_product(url)
  end
end
