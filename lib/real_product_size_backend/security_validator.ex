defmodule RealProductSizeBackend.SecurityValidator do
  @moduledoc """
  Comprehensive security validation and sanitization module.

  This module provides security validation for:
  - Input sanitization and validation
  - URL validation and security checks
  - SQL injection prevention
  - XSS prevention
  - Rate limiting
  - Authentication validation
  """

  require Logger

  @max_url_length 2048
  @max_string_length 1000
  @max_array_length 100
  @allowed_schemes ["http", "https"]
  @allowed_domains ["amazon.com", "amazon.co.jp", "amazon.co.uk", "amazon.de", "amazon.fr",
                   "amazon.ca", "amazon.com.au", "ikea.com", "walmart.com", "target.com"]

  @doc """
  Validates and sanitizes a URL for security.

  Returns {:ok, sanitized_url} or {:error, reason}
  """
  def validate_url(url) when is_binary(url) do
    with :ok <- validate_url_length(url),
         :ok <- validate_url_format(url),
         :ok <- validate_url_domain(url),
         :ok <- validate_url_security(url) do
      sanitized_url = sanitize_url(url)
      {:ok, sanitized_url}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_url(_), do: {:error, "URL must be a string"}

  @doc """
  Validates and sanitizes user input strings.

  Returns {:ok, sanitized_string} or {:error, reason}
  """
  def validate_string(input, opts \\ []) do
    max_length = Keyword.get(opts, :max_length, @max_string_length)
    allow_html = Keyword.get(opts, :allow_html, false)

    with :ok <- validate_string_length(input, max_length),
         :ok <- validate_string_content(input, allow_html) do
      sanitized = sanitize_string(input, allow_html)
      {:ok, sanitized}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates and sanitizes an array of strings.

  Returns {:ok, sanitized_array} or {:error, reason}
  """
  def validate_string_array(input, opts \\ []) when is_list(input) do
    max_length = Keyword.get(opts, :max_length, @max_string_length)
    max_array_length = Keyword.get(opts, :max_array_length, @max_array_length)

    with :ok <- validate_array_length(input, max_array_length) do
      sanitized_array =
        input
        |> Enum.take(max_array_length)
        |> Enum.map(&validate_string(&1, max_length: max_length))
        |> Enum.filter(fn
          {:ok, _} -> true
          {:error, _} -> false
        end)
        |> Enum.map(fn {:ok, value} -> value end)

      {:ok, sanitized_array}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates search query for security.

  Returns {:ok, sanitized_query} or {:error, reason}
  """
  def validate_search_query(query) when is_binary(query) do
    with :ok <- validate_string_length(query, 200),
         :ok <- validate_search_content(query) do
      sanitized = sanitize_search_query(query)
      {:ok, sanitized}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_search_query(_), do: {:error, "Search query must be a string"}

  @doc """
  Validates user ID for security.

  Returns {:ok, user_id} or {:error, reason}
  """
  def validate_user_id(user_id) when is_binary(user_id) do
    with :ok <- validate_string_length(user_id, 100),
         :ok <- validate_user_id_format(user_id) do
      {:ok, user_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_user_id(_), do: {:error, "User ID must be a string"}

  @doc """
  Validates product ID for security.

  Returns {:ok, product_id} or {:error, reason}
  """
  def validate_product_id(product_id) when is_binary(product_id) do
    with :ok <- validate_string_length(product_id, 100),
         :ok <- validate_product_id_format(product_id) do
      {:ok, product_id}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_product_id(_), do: {:error, "Product ID must be a string"}

  @doc """
  Validates pagination parameters for security.

  Returns {:ok, sanitized_params} or {:error, reason}
  """
  def validate_pagination_params(params) do
    page = validate_integer(params["page"], 1, 1000, 1)
    per_page = validate_integer(params["per_page"], 1, 100, 10)

    {:ok, %{page: page, per_page: per_page}}
  end

  @doc """
  Validates rate limiting for a user.

  Returns :ok or {:error, :rate_limited}
  """
  def validate_rate_limit(user_id, action, limits \\ %{}) do
    # This would integrate with a rate limiting service
    # For now, we'll implement basic rate limiting
    case check_rate_limit(user_id, action, limits) do
      :ok -> :ok
      {:error, :rate_limited} -> {:error, :rate_limited}
    end
  end

  # Private validation functions

  defp validate_url_length(url) do
    if String.length(url) <= @max_url_length do
      :ok
    else
      {:error, "URL too long (max #{@max_url_length} characters)"}
    end
  end

  defp validate_url_format(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in @allowed_schemes and not is_nil(host) ->
        :ok
      _ ->
        {:error, "Invalid URL format"}
    end
  end

  defp validate_url_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when not is_nil(host) ->
        if is_allowed_domain?(host) do
          :ok
        else
          {:error, "Domain not allowed"}
        end
      _ ->
        {:error, "Invalid host"}
    end
  end

  defp validate_url_security(url) do
    # Check for suspicious patterns
    suspicious_patterns = [
      ~r/script/i,
      ~r/javascript:/i,
      ~r/data:/i,
      ~r/vbscript:/i,
      ~r/onload/i,
      ~r/onerror/i,
      ~r/onclick/i
    ]

    if Enum.any?(suspicious_patterns, &String.match?(url, &1)) do
      {:error, "URL contains suspicious content"}
    else
      :ok
    end
  end

  defp validate_string_length(input, max_length) do
    if String.length(input) <= max_length do
      :ok
    else
      {:error, "String too long (max #{max_length} characters)"}
    end
  end

  defp validate_string_content(input, allow_html) do
    if allow_html do
      :ok
    else
      # Check for HTML/script tags
      html_patterns = [
        ~r/<script/i,
        ~r/<iframe/i,
        ~r/<object/i,
        ~r/<embed/i,
        ~r/<link/i,
        ~r/<meta/i,
        ~r/<style/i
      ]

      if Enum.any?(html_patterns, &String.match?(input, &1)) do
        {:error, "HTML content not allowed"}
      else
        :ok
      end
    end
  end

  defp validate_array_length(input, max_length) do
    if length(input) <= max_length do
      :ok
    else
      {:error, "Array too long (max #{max_length} items)"}
    end
  end

  defp validate_search_content(query) do
    # Check for SQL injection patterns
    sql_patterns = [
      ~r/union\s+select/i,
      ~r/drop\s+table/i,
      ~r/delete\s+from/i,
      ~r/insert\s+into/i,
      ~r/update\s+set/i,
      ~r/--/,
      ~r/\/\*/,
      ~r/\*\//
    ]

    if Enum.any?(sql_patterns, &String.match?(query, &1)) do
      {:error, "Search query contains suspicious content"}
    else
      :ok
    end
  end

  defp validate_user_id_format(user_id) do
    # UUID format validation
    uuid_pattern = ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if String.match?(user_id, uuid_pattern) do
      :ok
    else
      {:error, "Invalid user ID format"}
    end
  end

  defp validate_product_id_format(product_id) do
    # Allow alphanumeric and some special characters
    if String.match?(product_id, ~r/^[a-zA-Z0-9_-]+$/) do
      :ok
    else
      {:error, "Invalid product ID format"}
    end
  end

  defp validate_integer(value, min, max, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int >= min and int <= max -> int
      _ -> default
    end
  end

  defp validate_integer(value, min, max, default) when is_integer(value) do
    if value >= min and value <= max do
      value
    else
      default
    end
  end

  defp validate_integer(_, _, _, default), do: default

  # Sanitization functions

  defp sanitize_url(url) do
    url
    |> String.trim()
    |> String.replace(~r/\s+/, "")  # Remove whitespace
    |> String.downcase()
  end

  defp sanitize_string(input, allow_html) do
    input
    |> String.trim()
    |> then(fn str ->
      if allow_html do
        str
      else
        str
        |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
        |> String.replace(~r/&[a-zA-Z0-9#]+;/, "")  # Remove HTML entities
      end
    end)
  end

  defp sanitize_search_query(query) do
    query
    |> String.trim()
    |> String.replace(~r/[^\w\s-]/, "")  # Remove special characters except word chars, spaces, and hyphens
    |> String.replace(~r/\s+/, " ")  # Normalize whitespace
  end

  # Helper functions

  defp is_allowed_domain?(host) do
    # Check if host is in allowed domains or is a subdomain of allowed domains
    Enum.any?(@allowed_domains, fn allowed_domain ->
      host == allowed_domain or String.ends_with?(host, ".#{allowed_domain}")
    end)
  end

  defp check_rate_limit(user_id, action, limits) do
    # This would integrate with a proper rate limiting service
    # For now, we'll implement basic in-memory rate limiting
    case :ets.lookup(:rate_limits, {user_id, action}) do
      [{_, count, timestamp}] ->
        now = System.system_time(:second)
        if now - timestamp > 3600 do  # Reset after 1 hour
          :ets.insert(:rate_limits, {{user_id, action}, 1, now})
          :ok
        else
          max_requests = Map.get(limits, action, 100)
          if count < max_requests do
            :ets.insert(:rate_limits, {{user_id, action}, count + 1, timestamp})
            :ok
          else
            {:error, :rate_limited}
          end
        end

      [] ->
        :ets.insert(:rate_limits, {{user_id, action}, 1, System.system_time(:second)})
        :ok
    end
  end

  @doc """
  Initializes the security validator.
  """
  def init do
    :ets.new(:rate_limits, [:named_table, :public, :set])
    Logger.info("Security validator initialized")
    :ok
  end

  @doc """
  Test function for development.
  """
  def test_security_validation do
    # Test URL validation
    case validate_url("https://www.amazon.com/dp/B0F37TH3M3") do
      {:ok, url} -> Logger.info("URL validation passed: #{url}")
      {:error, reason} -> Logger.error("URL validation failed: #{reason}")
    end

    # Test string validation
    case validate_string("Test input", max_length: 100) do
      {:ok, str} -> Logger.info("String validation passed: #{str}")
      {:error, reason} -> Logger.error("String validation failed: #{reason}")
    end

    # Test search query validation
    case validate_search_query("laptop computer") do
      {:ok, query} -> Logger.info("Search query validation passed: #{query}")
      {:error, reason} -> Logger.error("Search query validation failed: #{reason}")
    end

    :ok
  end
end
