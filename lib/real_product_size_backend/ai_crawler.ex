defmodule RealProductSizeBackend.AiCrawler do
  @moduledoc """
  AI-powered Amazon product crawler using Gemini and Grok APIs.

  This module provides an alternative to the traditional HTML parsing crawler
  by leveraging AI models to extract product information from Amazon pages.
  """

  require Logger
  alias RealProductSizeBackend.AmazonCrawler

  alias RealProductSizeBackend.AiCrawler.{
    GeminiService,
    GrokService,
    OpenRouterService,
    ResponseParser,
    PromptEngine
  }

  @doc """
  Crawls an Amazon product page using AI and extracts product information.
  Optionally specifies the AI provider.

  ## Examples

      iex> AiCrawler.crawl_product("https://www.amazon.co.jp/dp/B0F37TH3M3")
      {:ok, %{title: "Product Title", price: "1234", ...}}

      iex> AiCrawler.crawl_product("https://www.amazon.co.jp/dp/B0F37TH3M3", :grok)
      {:ok, %{title: "Product Title", price: "1234", ...}}

  """
  def crawl_product(url, provider \\ nil) do
    with {:ok, validated_url} <- validate_url(url),
         {:ok, html_content} <- fetch_html_content(validated_url),
         {:ok, {product_data, debug_info}} <- extract_with_ai(html_content, validated_url, provider) do
      {:ok, {product_data, debug_info}}
    else
      {:error, {reason, debug_info}} when is_map(debug_info) ->
        Logger.error("AI crawler failed for #{url}: #{reason}")
        {:error, {reason, debug_info}}
      {:error, reason} ->
        Logger.error("AI crawler failed for #{url}: #{reason}")
        {:error, {reason, %{url: url, provider: provider}}}
    end
  end

  @doc """
  Crawls a product with fallback to traditional crawler if AI fails.
  """
  def crawl_product_with_fallback(url) do
    case crawl_product(url) do
      {:ok, product_data} ->
        {:ok, product_data}

      {:error, _reason} ->
        Logger.info("AI crawler failed, falling back to traditional crawler for #{url}")
        AmazonCrawler.crawl_product(url)
    end
  end

  @doc """
  Crawls multiple products concurrently with AI.
  """
  def crawl_products_batch(urls) when is_list(urls) do
    urls
    |> Enum.map(&Task.async(fn -> crawl_product(&1) end))
    |> Enum.map(&Task.await/1)
  end

  # Private functions

  defp validate_url(url) do
    # Basic URL validation for AI crawler - should work with any URL
    cond do
      not is_binary(url) or byte_size(url) == 0 ->
        {:error, "URL cannot be empty"}

      not String.starts_with?(url, ["http://", "https://"]) ->
        {:error, "URL must start with http:// or https://"}

      true ->
        {:ok, String.trim(url)}
    end
  end

  defp fetch_html_content(url) do
    # Use the same anti-bot headers as traditional crawler
    headers = [
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"},
      {"Upgrade-Insecure-Requests", "1"}
    ]

    case Req.get(url, headers: headers, receive_timeout: 30_000) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      {:ok, response} ->
        {:error, "HTTP request failed with status: #{response.status}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp extract_with_ai(html_content, url, provider) do
    # Check if AI extraction is enabled
    ai_crawler_config = Application.get_env(:real_product_size_backend, :ai_crawler, [])

    if ai_crawler_config[:enabled] do
      # NEW: Use focused content extraction instead of full HTML processing
      focused_data = RealProductSizeBackend.AiCrawler.FocusedContentExtractor.extract_focused_content(html_content, url)

      # Build structured prompt using focused data
      prompt = PromptEngine.build_product_extraction_prompt(focused_data, url)

      # Initialize debug info
      debug_info = %{
        focused_data: focused_data,
        prompt_sent: prompt,
        url: url,
        provider: provider
      }

      # Call AI service
      case call_ai_service(prompt, provider) do
        {:ok, {ai_response, service_debug}} ->
          debug_info = Map.merge(debug_info, service_debug)

          case ResponseParser.parse_product_data(ai_response) do
            {:ok, parsed_data} ->
              {:ok, {add_metadata(parsed_data, url, provider), debug_info}}
            {:error, parse_reason} ->
              debug_info = Map.put(debug_info, :parsing_error, parse_reason)
              Logger.error("AI extraction failed: #{parse_reason}")
              {:error, {parse_reason, debug_info}}
          end

        {:error, {service_reason, service_debug}} ->
          debug_info = Map.merge(debug_info, service_debug)
          Logger.error("AI extraction failed: #{service_reason}")
          {:error, {service_reason, debug_info}}

        # Handle legacy format for backward compatibility
        {:ok, ai_response} ->
          debug_info = Map.put(debug_info, :raw_response, ai_response)

          case ResponseParser.parse_product_data(ai_response) do
            {:ok, parsed_data} ->
              {:ok, {add_metadata(parsed_data, url, provider), debug_info}}
            {:error, parse_reason} ->
              debug_info = Map.put(debug_info, :parsing_error, parse_reason)
              Logger.error("AI extraction failed: #{parse_reason}")
              {:error, {parse_reason, debug_info}}
          end

        {:error, service_reason} ->
          debug_info = Map.put(debug_info, :service_error, service_reason)
          Logger.error("AI extraction failed: #{service_reason}")
          {:error, {service_reason, debug_info}}
      end
    else
      {:error, {"AI crawler is disabled", %{provider: provider, url: url}}}
    end
  end

  defp call_ai_service(prompt, provider) do
    ai_crawler_config = Application.get_env(:real_product_size_backend, :ai_crawler, [])
    provider = provider || ai_crawler_config[:provider] || :gemini

    case provider do
      :gemini -> GeminiService.extract_product_data(prompt)
      :grok -> GrokService.extract_product_data(prompt)
      :openrouter -> OpenRouterService.extract_product_data(prompt)
      _ -> {:error, "Unsupported AI provider: #{provider}"}
    end
  end









  defp add_metadata(product_data, url, provider) do
    ai_crawler_config = Application.get_env(:real_product_size_backend, :ai_crawler, [])
    used_provider = provider || ai_crawler_config[:provider] || :gemini

    product_data
    |> Map.put(:url, url)
    |> Map.put(:scraped_at, DateTime.utc_now())
    |> Map.put(:crawler_type, "ai")
    |> Map.put(:ai_provider, used_provider)
  end

  @doc """
  Test function for development.
  """
  def test_ai_crawl do
    url = "https://www.amazon.co.jp/dp/B0F37TH3M3?ref_=ast_sto_dp"
    crawl_product(url)
  end

  @doc """
  Test function with fallback.
  """
  def test_ai_crawl_with_fallback do
    url = "https://www.amazon.co.jp/dp/B0F37TH3M3?ref_=ast_sto_dp"
    crawl_product_with_fallback(url)
  end

  @doc """
  Get AI crawler statistics.
  """
  def get_ai_crawler_stats do
    ai_crawler_config = Application.get_env(:real_product_size_backend, :ai_crawler, [])

    %{
      enabled: ai_crawler_config[:enabled],
      provider: ai_crawler_config[:provider],
      max_html_size: ai_crawler_config[:max_html_size],
      cost_optimization: ai_crawler_config[:cost_optimization]
    }
  end







end
