defmodule RealProductSizeBackend.PlatformCrawler do
  @moduledoc """
  Dispatches crawling requests to platform-specific crawlers.

  This module acts as a facade for different e-commerce platform crawlers,
  providing a unified interface for product data extraction.
  """

  require Logger
  alias RealProductSizeBackend.{AmazonCrawler, IkeaCrawler, UrlValidator, UrlCategorizer, ProductCache, ProductValidator}

  @doc """
  Crawls a product from any supported platform.

  Returns {:ok, product_data} or {:error, reason}
  """
  def crawl_product(url) do
    # Try to get from cache first
    case ProductCache.get_or_crawl_product(url) do
      {:ok, cached_data} ->
        # Validate the cached data
        case ProductValidator.validate_product_data(cached_data) do
          {:ok, validated_data} ->
            {:ok, validated_data}

          {:error, validation_errors} ->
            Logger.warning("Cached data validation failed for #{url}: #{inspect(validation_errors)}")
            # Try graceful degradation with partial validation
            case ProductValidator.validate_partial_product(cached_data) do
              {:ok, partial_data} ->
                Logger.info("Using partial product data for #{url}")
                {:ok, partial_data}

              {:error, _reason} ->
                Logger.error("Product data too invalid for processing: #{url}")
                {:error, "Product data validation failed"}
            end
        end

      {:error, reason} ->
        Logger.error("Platform crawler failed for #{url}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Crawls a product without using cache (force fresh data).
  """
  def crawl_product_fresh(url) do
    with {:ok, platform, cleaned_url} <- UrlValidator.validate_url(url),
         {:ok, product_data} <- crawl_by_platform(platform, cleaned_url) do
      # Add platform metadata
      enhanced_data = Map.put(product_data, :platform, platform)

      # Categorize the product for AR suitability and processing priority
      categorization = UrlCategorizer.categorize_url(url, enhanced_data)

      # Add categorization metadata
      final_data = Map.merge(enhanced_data, %{
        ar_suitable: categorization.ar_suitable,
        product_type: categorization.product_type,
        size_relevance_score: categorization.size_relevance_score,
        category_metadata: categorization.category
      })

      # Store in cache for future use
      ProductCache.store_in_cache(url, final_data)

      {:ok, final_data}
    else
      {:error, reason} ->
        Logger.error("Platform crawler failed for #{url}: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Crawls a product with fallback to alternative crawlers.
  """
  def crawl_product_with_fallback(url) do
    case crawl_product(url) do
      {:ok, product_data} ->
        {:ok, product_data}

      {:error, _reason} ->
        Logger.info("Primary crawler failed, attempting fallback for #{url}")
        # For now, we only have one crawler per platform
        # In the future, we can implement cross-platform fallbacks
        {:error, "All crawlers failed"}
    end
  end

  @doc """
  Crawls multiple products concurrently.
  """
  def crawl_products_batch(urls) when is_list(urls) do
    urls
    |> Enum.map(&Task.async(fn -> crawl_product(&1) end))
    |> Enum.map(&Task.await/1)
  end

  @doc """
  Gets the appropriate crawler for a platform.
  """
  def get_crawler_for_platform(platform) do
    case platform do
      :amazon -> AmazonCrawler
      :ikea -> IkeaCrawler
      _ -> {:error, "Unsupported platform: #{platform}"}
    end
  end

  # Private functions

  defp crawl_by_platform(platform, url) do
    case platform do
      :amazon ->
        AmazonCrawler.crawl_product(url)

      :ikea ->
        IkeaCrawler.crawl_product(url)

      _ ->
        {:error, "Unsupported platform: #{platform}"}
    end
  end

  @doc """
  Test function for development.
  """
  def test_crawl do
    test_urls = [
      "https://www.amazon.com/dp/B0F37TH3M3",
      "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/",
      "https://a.co/d/ft3bEVK"
    ]

    Enum.each(test_urls, fn url ->
      case crawl_product(url) do
        {:ok, product_data} ->
          Logger.info("Successfully crawled #{url}: #{product_data.title}")

        {:error, reason} ->
          Logger.error("Failed to crawl #{url}: #{reason}")
      end
    end)
  end
end
