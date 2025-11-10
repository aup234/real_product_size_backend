defmodule RealProductSizeBackend.UrlValidator do
  @moduledoc """
  Comprehensive URL validation and resolution system for multiple e-commerce platforms.

  Supports:
  - Amazon (including shortened URLs like a.co)
  - IKEA
  - Future platforms can be easily added
  """

  require Logger
  alias RealProductSizeBackend.UrlResolver

  @doc """
  Validates and categorizes URLs from supported e-commerce platforms.

  Returns {:ok, platform, cleaned_url} or {:error, reason}
  """
  def validate_url(url) when is_binary(url) do
    with {:ok, normalized_url} <- normalize_url(url),
         {:ok, platform, cleaned_url} <- categorize_url(normalized_url) do
      {:ok, platform, cleaned_url}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_url(_), do: {:error, "URL must be a string"}

  @doc """
  Resolves shortened URLs to their full form.
  """
  def resolve_shortened_url(url) do
    UrlResolver.resolve_redirect(url)
  end

  @doc """
  Extracts product ID from a validated URL.
  """
  def extract_product_id(platform, url) do
    case platform do
      :amazon -> extract_amazon_product_id(url)
      :ikea -> extract_ikea_product_id(url)
      _ -> {:error, "Unsupported platform: #{platform}"}
    end
  end

  @doc """
  Checks if a URL is suitable for AR visualization.
  """
  def is_ar_suitable?(platform, url) do
    case platform do
      :amazon -> is_amazon_ar_suitable?(url)
      :ikea -> is_ikea_ar_suitable?(url)
      _ -> false
    end
  end

  # Private functions

  defp normalize_url(url) do
    cond do
      not is_binary(url) or byte_size(url) == 0 ->
        {:error, "URL cannot be empty"}

      not String.starts_with?(url, ["http://", "https://"]) ->
        {:error, "URL must start with http:// or https://"}

      true ->
        {:ok, String.trim(url)}
    end
  end

  defp categorize_url(url) do
    cond do
      # Amazon URLs (including shortened)
      is_amazon_url?(url) ->
        case resolve_amazon_url(url) do
          {:ok, cleaned_url} -> {:ok, :amazon, cleaned_url}
          {:error, reason} -> {:error, reason}
        end

      # IKEA URLs
      is_ikea_url?(url) ->
        case validate_ikea_url(url) do
          {:ok, cleaned_url} -> {:ok, :ikea, cleaned_url}
          {:error, reason} -> {:error, reason}
        end

      # Shortened URLs that need resolution
      is_shortened_url?(url) ->
        case resolve_shortened_url(url) do
          {:ok, resolved_url} -> categorize_url(resolved_url)
          {:error, reason} -> {:error, "Failed to resolve shortened URL: #{reason}"}
        end

      true ->
        {:error, "Unsupported e-commerce platform"}
    end
  end

  # Amazon URL detection and validation
  defp is_amazon_url?(url) do
    String.contains?(url, "amazon.") or
    String.starts_with?(url, "https://a.co/") or
    String.starts_with?(url, "https://amzn.to/")
  end

  defp resolve_amazon_url(url) do
    cond do
      # Shortened Amazon URLs
      String.starts_with?(url, "https://a.co/") or String.starts_with?(url, "https://amzn.to/") ->
        case resolve_shortened_url(url) do
          {:ok, resolved_url} -> validate_amazon_url(resolved_url)
          {:error, reason} -> {:error, "Failed to resolve Amazon shortened URL: #{reason}"}
        end

      # Regular Amazon URLs
      true ->
        validate_amazon_url(url)
    end
  end

  defp validate_amazon_url(url) do
    cond do
      # Check if it's a product page
      not (String.contains?(url, "/dp/") or String.contains?(url, "/gp/product/")) ->
        {:error, "URL must be a product page (contains /dp/ or /gp/product/)"}

      # Check if it's a search or category page
      String.contains?(url, "/s?") or String.contains?(url, "/b/") ->
        {:error, "URL cannot be a search or category page"}

      true ->
        {:ok, clean_url(url)}
    end
  end

  # IKEA URL detection and validation
  defp is_ikea_url?(url) do
    String.contains?(url, "ikea.com")
  end

  defp validate_ikea_url(url) do
    # IKEA URL pattern: https://www.ikea.com/{country_code}/{language_code}/p/{product_name}-{product_id}/
    ikea_pattern = ~r/^https:\/\/www\.ikea\.com\/[a-z]{2}\/[a-z]{2}\/p\/[^\/]+-\d+\//

    if Regex.match?(ikea_pattern, url) do
      {:ok, clean_url(url)}
    else
      {:error, "Invalid IKEA product URL format"}
    end
  end

  # Shortened URL detection
  defp is_shortened_url?(url) do
    shortened_domains = [
      "a.co", "amzn.to", "bit.ly", "tinyurl.com", "short.link",
      "t.co", "goo.gl", "ow.ly", "is.gd"
    ]

    Enum.any?(shortened_domains, fn domain ->
      String.contains?(url, domain)
    end)
  end

  # Product ID extraction
  defp extract_amazon_product_id(url) do
    # Extract ASIN from Amazon URL
    patterns = [
      ~r/\/dp\/([A-Z0-9]{10})/,
      ~r/\/gp\/product\/([A-Z0-9]{10})/,
      ~r/\/product\/([A-Z0-9]{10})/
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, url) do
        [_, asin] -> {:ok, asin}
        _ -> nil
      end
    end) || {:error, "Could not extract Amazon product ID"}
  end

  defp extract_ikea_product_id(url) do
    # Extract product ID from IKEA URL
    pattern = ~r{/p/[^/]+-(\d+)/}

    case Regex.run(pattern, url) do
      [_, product_id] -> {:ok, product_id}
      _ -> {:error, "Could not extract IKEA product ID"}
    end
  end

  # AR suitability checks
  defp is_amazon_ar_suitable?(_url) do
    # For now, assume all Amazon product pages are AR suitable
    # In the future, we can add category-based filtering
    true
  end

  defp is_ikea_ar_suitable?(_url) do
    # IKEA products are generally suitable for AR
    # We can add more sophisticated filtering based on product category
    true
  end

  defp clean_url(url) do
    url
    |> String.split("?")
    |> List.first()
    |> String.split("#")
    |> List.first()
  end
end
