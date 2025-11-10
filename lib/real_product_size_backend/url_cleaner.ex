defmodule RealProductSizeBackend.UrlCleaner do
  @moduledoc """
  Module for cleaning URLs by removing unnecessary query parameters.
  """

  @doc """
  Cleans a URL by removing unnecessary query parameters and keeping only essential ones.

  ## Parameters
  - `url`: The URL to clean
  - `essential_params`: List of essential parameter names to keep (optional)

  ## Returns
  - Cleaned URL string

  ## Examples
      iex> UrlCleaner.clean_url("https://amazon.com/product?id=123&ref=abc&utm_source=google", ["id"])
      "https://amazon.com/product?id=123"

      iex> UrlCleaner.clean_url("https://amazon.com/product?id=123&ref=abc&utm_source=google")
      "https://amazon.com/product?id=123"
  """
  def clean_url(url, essential_params \\ nil) do
    case URI.parse(url) do
      %URI{scheme: nil} -> url  # Invalid URL, return as is
      uri ->
        essential_params = essential_params || get_essential_params_for_domain(uri.host)

        # For Amazon URLs, clean the path to only include up to /dp/PRODUCT_ID/
        cleaned_path = if is_amazon_domain?(uri.host) do
          clean_amazon_path(uri.path)
        else
          uri.path
        end

        # Filter query parameters to keep only essential ones
        filtered_params =
          uri.query
          |> decode_query_params()
          |> filter_essential_params(essential_params)
          |> encode_query_params()

        # Reconstruct the URL
        cleaned_uri = %URI{uri | path: cleaned_path, query: filtered_params}
        URI.to_string(cleaned_uri)
    end
  end

  defp is_amazon_domain?(host) do
    case host do
      host when host in ["amazon.com", "amazon.co.jp", "amazon.de", "amazon.co.uk", "amazon.fr", "amazon.ca"] ->
        true
      host when host in ["www.amazon.com", "www.amazon.co.jp", "www.amazon.de", "www.amazon.co.uk", "www.amazon.fr", "www.amazon.ca"] ->
        true
      _ ->
        false
    end
  end

  defp clean_amazon_path(path) do
    case Regex.run(~r/.*(\/dp\/[A-Z0-9]+).*/, path) do
      [_, dp_part] -> dp_part <> "/"
      nil -> path  # No dp pattern found, return original
    end
  end

  @doc """
  Gets essential parameters for a specific domain.
  """
  def get_essential_params_for_domain(host) do
    case host do
      host when host in ["amazon.com", "amazon.co.jp", "amazon.de", "amazon.co.uk", "amazon.fr", "amazon.ca"] ->
        ["dp"]  # Only keep dp parameter for Amazon - it contains the product ID
      host when host in ["ebay.com", "ebay.co.uk", "ebay.de"] ->
        ["item", "hash", "var"]
      host when host in ["walmart.com"] ->
        ["id", "item_id"]
      host when host in ["target.com"] ->
        ["id", "A-"]
      _ ->
        ["id", "item", "product", "pid", "sku"]
    end
  end

  defp decode_query_params(nil), do: %{}
  defp decode_query_params(query_string) do
    query_string
    |> URI.decode_query()
  end

  defp filter_essential_params(params, essential_params) do
    params
    |> Enum.filter(fn {key, _value} ->
      # For Amazon, only keep the dp parameter (contains product ID)
      # For other sites, use the general filtering logic
      if "dp" in essential_params do
        key == "dp"  # Only keep dp parameter for Amazon - everything else is removed
      else
        key != "content-id" and (
          key in essential_params or
          String.contains?(key, "id") or
          String.contains?(key, "item") or
          String.contains?(key, "product") or
          String.contains?(key, "sku") or
          String.contains?(key, "pid")
        )
      end
    end)
    |> Enum.into(%{})
  end

  defp encode_query_params(%{} = params) when map_size(params) == 0, do: nil
  defp encode_query_params(params) do
    params
    |> URI.encode_query()
  end

  @doc """
  Gets a clean URL for display purposes, showing both original and cleaned versions.
  """
  def get_display_urls(original_url) do
    cleaned_url = clean_url(original_url)

    %{
      original: original_url,
      cleaned: cleaned_url,
      is_cleaned: original_url != cleaned_url
    }
  end
end
