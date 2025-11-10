defmodule RealProductSizeBackend.UrlResolver do
  @moduledoc """
  Handles resolution of shortened URLs to their full form.

  This module follows redirects to resolve shortened URLs like:
  - https://a.co/d/ft3bEVK -> https://www.amazon.com/dp/B0F37TH3M3
  - https://amzn.to/xyz -> full Amazon URL
  - Other shortened URL services
  """

  require Logger

  @max_redirects 5
  @timeout 10_000

  @doc """
  Resolves a shortened URL by following redirects.

  Returns {:ok, resolved_url} or {:error, reason}
  """
  def resolve_redirect(url) when is_binary(url) do
    resolve_redirect(url, @max_redirects, [])
  end

  def resolve_redirect(_), do: {:error, "URL must be a string"}

  defp resolve_redirect(url, remaining_redirects, visited_urls) do
    cond do
      remaining_redirects <= 0 ->
        {:error, "Too many redirects"}

      url in visited_urls ->
        {:error, "Circular redirect detected"}

      true ->
        case make_head_request(url) do
          {:ok, %{status: status, headers: _headers}} when status in 200..299 ->
            {:ok, url}

          {:ok, %{status: status, headers: headers}} when status in 300..399 ->
            case get_redirect_location(headers) do
              {:ok, redirect_url} ->
                resolve_redirect(redirect_url, remaining_redirects - 1, [url | visited_urls])

              {:error, reason} ->
                {:error, "No redirect location found: #{reason}"}
            end

          {:ok, %{status: status}} ->
            {:error, "HTTP error: #{status}"}

          {:error, reason} ->
            {:error, "Request failed: #{inspect(reason)}"}
        end
    end
  end

  defp make_head_request(url) do
    RealProductSizeBackend.CircuitBreaker.call_with_circuit_breaker(
      :url_resolve_api,
      fn -> do_head_request(url) end,
      fn -> {:error, :service_unavailable} end
    )
  end

  defp do_head_request(url) do
    headers = [
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"}
    ]

    case Req.head(url, headers: headers, timeout: @timeout) do
      {:ok, response} ->
        {:ok, response}

      {:error, exception} ->
        # Handle different types of Req errors
        case exception do
          %Mint.TransportError{reason: :timeout} ->
            {:error, "Request timeout"}

          %Mint.TransportError{reason: reason} ->
            {:error, "Transport error: #{reason}"}

          %{reason: reason} when is_atom(reason) ->
            {:error, "Request failed: #{reason}"}

          %{message: message} ->
            {:error, "Request failed: #{message}"}

          _ ->
            {:error, "Request failed: #{inspect(exception)}"}
        end
    end
  end

  defp get_redirect_location(headers) do
    case Enum.find(headers, fn {key, _value} -> String.downcase(key) == "location" end) do
      {_key, location} ->
        # Handle relative URLs
        if String.starts_with?(location, "http") do
          {:ok, location}
        else
          # This is a simplified relative URL handler
          # In production, you might want more sophisticated URL resolution
          {:error, "Relative redirect URLs not supported"}
        end

      nil ->
        {:error, "No location header found"}
    end
  end

  @doc """
  Test function for development.
  """
  def test_resolve do
    test_urls = [
      "https://a.co/d/ft3bEVK",
      "https://amzn.to/xyz",
      "https://www.amazon.com/dp/B0F37TH3M3"
    ]

    Enum.each(test_urls, fn url ->
      case resolve_redirect(url) do
        {:ok, resolved} ->
          Logger.info("Resolved #{url} -> #{resolved}")

        {:error, reason} ->
          Logger.error("Failed to resolve #{url}: #{reason}")
      end
    end)
  end
end
