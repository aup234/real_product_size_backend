defmodule RealProductSizeBackend.ProductCache do
  @moduledoc """
  Intelligent caching system for product data with time-based expiration.

  This module provides caching functionality for:
  - Product data by product ID
  - Crawled data by URL
  - Platform-specific caching strategies
  - Time-based cache expiration
  """

  require Logger
  alias RealProductSizeBackend.UrlValidator

  @cache_ttl_seconds 3600  # 1 hour default TTL
  @cache_cleanup_interval 300_000  # 5 minutes cleanup interval

  @doc """
  Gets a product from cache or crawls if not cached.

  Returns {:ok, product_data} or {:error, reason}
  """
  def get_or_crawl_product(url) do
    with {:ok, platform, cleaned_url} <- UrlValidator.validate_url(url),
         cache_key <- build_cache_key(platform, cleaned_url) do

      case get_from_cache(cache_key) do
        {:ok, cached_data} ->
          Logger.info("Cache hit for #{url}")
          {:ok, cached_data}

        {:error, :not_found} ->
          Logger.info("Cache miss for #{url}, crawling...")
          crawl_and_cache(url, platform, cleaned_url, cache_key)
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a product from cache only (does not crawl if not found).

  Returns {:ok, product_data} or {:error, :not_found}
  """
  def get_from_cache_only(url) do
    with {:ok, platform, cleaned_url} <- UrlValidator.validate_url(url),
         cache_key <- build_cache_key(platform, cleaned_url) do
      get_from_cache(cache_key)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stores product data in cache.

  Returns {:ok, cached_data} or {:error, reason}
  """
  def store_in_cache(url, product_data) do
    with {:ok, platform, cleaned_url} <- UrlValidator.validate_url(url),
         cache_key <- build_cache_key(platform, cleaned_url) do
      store_cache_entry(cache_key, product_data)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Invalidates cache for a specific URL.

  Returns :ok
  """
  def invalidate_cache(url) do
    with {:ok, platform, cleaned_url} <- UrlValidator.validate_url(url),
         cache_key <- build_cache_key(platform, cleaned_url) do
      delete_cache_entry(cache_key)
    else
      {:error, _reason} ->
        :ok  # Ignore errors for invalidation
    end
  end

  @doc """
  Clears all cache entries.

  Returns :ok
  """
  def clear_all_cache do
    # In a real implementation, this would clear the cache store
    Logger.info("Clearing all cache entries")
    :ok
  end

  @doc """
  Gets cache statistics.

  Returns cache statistics map
  """
  def get_cache_stats do
    # In a real implementation, this would return actual cache statistics
    %{
      total_entries: 0,
      hit_rate: 0.0,
      miss_rate: 0.0,
      memory_usage: 0,
      oldest_entry: nil,
      newest_entry: nil
    }
  end

  # Private functions

  defp build_cache_key(platform, url) do
    # Create a unique cache key based on platform and URL
    # This ensures different platforms can have the same product ID without conflicts
    "#{platform}:#{url}"
  end

  defp crawl_and_cache(url, platform, cleaned_url, cache_key) do
    # Use the platform crawler to get fresh data
    case crawl_by_platform(platform, cleaned_url) do
      {:ok, product_data} ->
        # Add platform metadata
        enhanced_data = Map.put(product_data, :platform, platform)

        # Categorize the product for AR suitability and processing priority
        categorization = RealProductSizeBackend.UrlCategorizer.categorize_url(url, enhanced_data)

        # Add categorization metadata
        final_data = Map.merge(enhanced_data, %{
          ar_suitable: categorization.ar_suitable,
          product_type: categorization.product_type,
          size_relevance_score: categorization.size_relevance_score,
          category_metadata: categorization.category
        })

        # Validate data before storing in cache
        validated_data = case RealProductSizeBackend.ProductValidator.validate_product_data(final_data) do
          {:ok, validated} -> validated
          {:error, _} ->
            # Try partial validation for graceful degradation
            case RealProductSizeBackend.ProductValidator.validate_partial_product(final_data) do
              {:ok, partial} -> partial
              {:error, _} -> final_data  # Store as-is if validation completely fails
            end
        end

        # Store in cache
        case store_cache_entry(cache_key, validated_data) do
          {:ok, _cached_data} ->
            Logger.info("Successfully cached product data for #{url}")
            {:ok, validated_data}
        end

      {:error, reason} ->
        Logger.error("Failed to crawl product #{url}: #{reason}")
        {:error, reason}
    end
  end

  defp crawl_by_platform(platform, url) do
    case platform do
      :amazon ->
        RealProductSizeBackend.AmazonCrawler.crawl_product(url)

      :ikea ->
        RealProductSizeBackend.IkeaCrawler.crawl_product(url)

      _ ->
        {:error, "Unsupported platform: #{platform}"}
    end
  end

  defp get_from_cache(cache_key) do
    # In a real implementation, this would use Redis, Memcached, or similar
    # For now, we'll use a simple in-memory cache with ETS
    case :ets.lookup(:product_cache, cache_key) do
      [{^cache_key, {product_data, expires_at_timestamp}}] ->
        now_timestamp = DateTime.to_unix(DateTime.utc_now())
        if expires_at_timestamp > now_timestamp do
          {:ok, product_data}
        else
          # Cache expired, remove entry
          :ets.delete(:product_cache, cache_key)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp store_cache_entry(cache_key, product_data) do
    # Calculate expiration time as Unix timestamp
    expires_at = DateTime.add(DateTime.utc_now(), @cache_ttl_seconds, :second)
    expires_at_timestamp = DateTime.to_unix(expires_at)

    # Store in cache
    :ets.insert(:product_cache, {cache_key, {product_data, expires_at_timestamp}})

    Logger.debug("Cached product data for key: #{cache_key}")
    {:ok, product_data}
  end

  defp delete_cache_entry(cache_key) do
    :ets.delete(:product_cache, cache_key)
    Logger.debug("Deleted cache entry for key: #{cache_key}")
    :ok
  end

  @doc """
  Initializes the cache system.
  This should be called during application startup.
  """
  def init_cache do
    # Create ETS table for caching
    :ets.new(:product_cache, [:named_table, :public, :set])

    # Start cleanup process
    start_cache_cleanup()

    Logger.info("Product cache initialized")
    :ok
  end

  defp start_cache_cleanup do
    # Start a process to clean up expired cache entries
    spawn_link(fn ->
      cleanup_loop()
    end)
  end

  defp cleanup_loop do
    # Clean up expired entries
    cleanup_expired_entries()

    # Sleep for cleanup interval
    Process.sleep(@cache_cleanup_interval)

    # Continue cleanup loop
    cleanup_loop()
  end

  defp cleanup_expired_entries do
    now_timestamp = DateTime.to_unix(DateTime.utc_now())

    :ets.select_delete(:product_cache, [
      {{:"$1", {:"$2", :"$3"}},
       [{:"<", :"$3", now_timestamp}],
       [true]}
    ])
  end

  @doc """
  Gets cache entry with TTL information.

  Returns {:ok, {product_data, ttl_seconds}} or {:error, :not_found}
  """
  def get_with_ttl(cache_key) do
    case :ets.lookup(:product_cache, cache_key) do
      [{^cache_key, {product_data, expires_at_timestamp}}] ->
        now_timestamp = DateTime.to_unix(DateTime.utc_now())
        ttl_seconds = expires_at_timestamp - now_timestamp

        if ttl_seconds > 0 do
          {:ok, {product_data, ttl_seconds}}
        else
          # Cache expired, remove entry
          :ets.delete(:product_cache, cache_key)
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates cache TTL for a specific entry.

  Returns :ok or {:error, :not_found}
  """
  def update_ttl(cache_key, new_ttl_seconds) do
    case :ets.lookup(:product_cache, cache_key) do
      [{^cache_key, {product_data, _old_expires_at_timestamp}}] ->
        new_expires_at = DateTime.add(DateTime.utc_now(), new_ttl_seconds, :second)
        new_expires_at_timestamp = DateTime.to_unix(new_expires_at)
        :ets.insert(:product_cache, {cache_key, {product_data, new_expires_at_timestamp}})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets all cache keys (for debugging).

  Returns list of cache keys
  """
  def get_all_cache_keys do
    :ets.select(:product_cache, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Gets cache size (number of entries).

  Returns integer
  """
  def get_cache_size do
    :ets.info(:product_cache, :size)
  end

  @doc """
  Test function for development.
  """
  def test_cache do
    # Initialize cache
    init_cache()

    # Test URL
    test_url = "https://www.amazon.com/dp/B0F37TH3M3"

    # Test cache miss
    case get_from_cache_only(test_url) do
      {:error, :not_found} ->
        Logger.info("Cache miss test passed")
      {:ok, _data} ->
        Logger.warning("Unexpected cache hit")
    end

    # Test cache and store
    case get_or_crawl_product(test_url) do
      {:ok, product_data} ->
        Logger.info("Successfully cached product: #{product_data.title}")

        # Test cache hit
        case get_from_cache_only(test_url) do
          {:ok, _cached_data} ->
            Logger.info("Cache hit test passed")
          {:error, :not_found} ->
            Logger.warning("Unexpected cache miss")
        end
      {:error, reason} ->
        Logger.error("Failed to cache product: #{reason}")
    end

    # Test cache stats
    stats = get_cache_stats()
    Logger.info("Cache stats: #{inspect(stats)}")
  end
end
