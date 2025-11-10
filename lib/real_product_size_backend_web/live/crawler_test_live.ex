defmodule RealProductSizeBackendWeb.CrawlerTestLive do
  use RealProductSizeBackendWeb, :live_view

  alias RealProductSizeBackend.AiCrawler
  alias RealProductSizeBackend.AiCrawler.ResponseParser
  alias RealProductSizeBackend.AiCrawler.FocusedContentExtractor
  alias RealProductSizeBackend.PlatformCrawler
  alias RealProductSizeBackend.UrlCleaner

  @test_urls [
    # Amazon URLs
    %{"label" => "Japanese Wet Tissue Case", "url" => "https://www.amazon.co.jp/dp/B09TKNK6XB?ref_=ast_sto_dp&th=1", "description" => "ideaco Mochi Bin Roll Type", "region" => "JP", "website" => "Amazon"},
    %{"label" => "Japanese Tissue Holder", "url" => "https://www.amazon.co.jp/-/en/Sarasa-Design-Tissue-White-Holder/dp/B0BD4KBVJV/?_encoding=UTF8&pd_rd_w=eHxPF&content-id=amzn1.sym.551ca070-bd7a-4db2-b5f1-f411b49f7503:amzn1.symc.e90efe59-ef21-415f-acbc-33d037799b12&pf_rd_p=551ca070-bd7a-4db2-b5f1-f411b49f7503&pf_rd_r=6QDXFTXD4AHXC3199FTX&pd_rd_wg=Jjjzg&pd_rd_r=0e11ef1f-e051-489b-8d72-c4c0e7623af0&ref_=pd_hp_d_btf_ci_mcx_mr_ca_id_hp_d&th=1", "description" => "Sarasa Design Tissue Holder", "region" => "JP", "website" => "Amazon"},
    %{"label" => "US Kitchen Product", "url" => "https://www.amazon.com/Ninja-NC301-placeholder-Cream-Maker/dp/B08QXB9BH5/ref=sr_1_20?_encoding=UTF8&content-id=amzn1.sym.8158743a-e3ec-4239-b3a8-31bfee7d4a15&dib=eyJ2IjoiMSJ9.86Z3IXb_FGtRbGjkJMxkGKGjRvsd16no0elD6zqRpup2BV4fw7h8MFeGH8g4hM4JviJmbao7WZjxWqB292u19PNJA4lqWmb5NT6upvvugWTEJsOSyf27_whU9a8SgalHJGAzAtzkObg61e8td4k6QCw7U3umpskRF7v0P8ebByFltykbvHwQRcqhXNYxnLbIdZS8tF-YOBCzmYW_un9Zr4UtkhL96XucY4IwZa8xL4il_1G5Th0sXopopErnTUD7qPYhE5ochrnN_LAWtbFCXC_RSr_6MpOndrkKbNYhSVY.iFjfF48u0-6UwvbJ8gZxJbOhnvdipb62sYX0LLaC1Z8&dib_tag=se&keywords=kitchen%2Bproducts&pd_rd_r=7f1e9ebc-777f-49c6-b2bf-c2a4f0584c9c&pd_rd_w=Weiwb&pd_rd_wg=OFXwT&qid=1759360925&sr=8-20&th=1", "description" => "Ninja Cream Maker", "region" => "US", "website" => "Amazon"},
    %{"label" => "German Coffee Table", "url" => "https://www.amazon.de/Mobilifiver-Couchtisch-Emma-matt-wei%C3%9F/dp/B075NQSRHJ/ref=s9_acsd_al_ot_c2_x_1_t?_encoding=UTF8&pf_rd_m=A1PA6795UKMFR9&pf_rd_s=merchandised-search-2&pf_rd_r=28RSVYY72NM8ZE2GXV2Z&pf_rd_p=a1a88376-f2a4-491e-8c3d-dd21d81d91c2&pf_rd_t=&pf_rd_i=16749871031&th=1", "description" => "Mobilifiver Coffee Table", "region" => "DE", "website" => "Amazon"},

    # Muji URLs
    %{"label" => "Muji USA Dining Table", "url" => "https://www.muji.us/collections/dining-tables/products/beech-wood-table-with-round-legs-w150cm", "description" => "Beech Wood Table with Round Legs", "region" => "US", "website" => "Muji"},
    %{"label" => "Muji Japan Product", "url" => "https://www.muji.com/jp/ja/store/cmdty/detail/4550584472688", "description" => "Muji Japan Product", "region" => "JP", "website" => "Muji"},
    %{"label" => "Muji Hong Kong Product", "url" => "https://onlineshop.muji.com.hk/products/4547315880164", "description" => "Muji Hong Kong Product", "region" => "HK", "website" => "Muji"},

    # IKEA URLs
    %{"label" => "IKEA Desk", "url" => "https://www.ikea.com/us/en/p/bekant-desk-sit-stand-white-s29260998/", "description" => "BEKANT Desk", "region" => "US", "website" => "IKEA"},
    %{"label" => "IKEA Chair", "url" => "https://www.ikea.com/us/en/p/markus-office-chair-vissle-dark-gray-90289172/", "description" => "MARKUS Chair", "region" => "US", "website" => "IKEA"},

    # Walmart URLs
    %{"label" => "Walmart Electronics", "url" => "https://www.walmart.com/ip/Apple-iPhone-15-128GB-Blue/504186184", "description" => "iPhone 15", "region" => "US", "website" => "Walmart"},

    # Target URLs
    %{"label" => "Target Home", "url" => "https://www.target.com/p/room-essentials-3-tier-shelf/-/A-13399320", "description" => "3-Tier Shelf", "region" => "US", "website" => "Target"},

    # Non-product URLs (for testing error handling)
    %{"label" => "Search Results (Non-Product)", "url" => "https://www.amazon.co.jp/s?k=books", "description" => "Books search page", "region" => "JP", "website" => "Amazon"},
    %{"label" => "Generic Website", "url" => "https://example.com/product/123", "description" => "Generic product page", "region" => "Generic", "website" => "Generic"}
  ]

  defp get_url_from_item(item), do: item["url"]

  defp get_website_logo(website) do
    case website do
      "Amazon" -> "/images/logos/amazon-logo.png"
      "Muji" -> "/images/logos/muji-logo.png"
      "IKEA" -> "/images/logos/ikea-logo.png"
      "Walmart" -> "/images/logos/walmart-logo.png"
      "Target" -> "/images/logos/target-logo.png"
      "Generic" -> "/images/logos/generic-logo.png"
      _ -> "/images/logos/generic-logo.png"
    end
  end

  defp get_website_logo_by_type(website_type) do
    case website_type do
      :amazon -> "/images/logos/amazon-logo.png"
      :muji -> "/images/logos/muji-logo.png"
      :ikea -> "/images/logos/ikea-logo.png"
      :walmart -> "/images/logos/walmart-logo.png"
      :target -> "/images/logos/target-logo.png"
      :generic -> "/images/logos/generic-logo.png"
      _ -> "/images/logos/generic-logo.png"
    end
  end

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

  @impl true
  def mount(_params, _session, socket) do
    predefined_urls = @test_urls

    crawlers = [
      {"Traditional Crawler", "traditional"},
      {"Grok AI", "grok"},
      {"Gemini AI", "gemini"},
      {"OpenRouter AI", "openrouter"}
    ]

    ai_crawler_config = Application.get_env(:real_product_size_backend, :ai_crawler, [])

    config = %{
      ai_crawler_enabled: ai_crawler_config[:enabled] || false,
      default_provider: ai_crawler_config[:provider] || :gemini,
      max_html_size: ai_crawler_config[:max_html_size] || 50000,
      grok_api_key: mask_api_key(Application.get_env(:real_product_size_backend, :grok_api_key, "")),
      gemini_api_key: mask_api_key(Application.get_env(:real_product_size_backend, :gemini_api_key, "")),
      openrouter_api_key: mask_api_key(Application.get_env(:real_product_size_backend, :openrouter_api_key, ""))
    }

    socket =
      socket
      |> assign(predefined_urls: predefined_urls)
      |> assign(crawlers: crawlers)
      |> assign(config: config)
      |> assign(url: "")
      |> assign(cleaned_url: "")
      |> assign(url_display_info: nil)
      |> assign(crawler: "grok")
      |> assign(product_data: nil)
      |> assign(quality_info: nil)
      |> assign(error: nil)
      |> assign(formatted_data: nil)
      |> assign(job_id: nil)
      |> assign(job_status: nil)
      |> assign(loading: false)
      |> assign(debug_info: nil)
      |> assign(raw_prompt: nil)
      |> assign(raw_response: nil)
      |> assign(extracted_html_data: nil)
      |> assign(parsing_error: nil)
      |> assign(website_type: nil)
      |> assign(website_adapter: nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_url", %{"url" => url}, socket) do
    cleaned_url = UrlCleaner.clean_url(url)
    url_display_info = UrlCleaner.get_display_urls(url)

    # Detect website type and adapter
    website_type = FocusedContentExtractor.detect_website_type(url)
    website_adapter = FocusedContentExtractor.get_website_adapter(website_type)

    {:noreply, assign(socket,
      url: url,
      cleaned_url: cleaned_url,
      url_display_info: url_display_info,
      website_type: website_type,
      website_adapter: website_adapter,
      error: nil,
      product_data: nil,
      quality_info: nil,
      formatted_data: nil,
      debug_info: nil,
      raw_prompt: nil,
      raw_response: nil,
      extracted_html_data: nil,
      parsing_error: nil
    )}
  end

  @impl true
  def handle_event("select_crawler", %{"crawler" => crawler}, socket) do
    {:noreply, assign(socket, crawler: crawler, error: nil, product_data: nil, quality_info: nil, formatted_data: nil, debug_info: nil, raw_prompt: nil, raw_response: nil, extracted_html_data: nil, parsing_error: nil)}
  end

  @impl true
  def handle_event("url_changed", %{"url" => url}, socket) do
    url = String.trim(url)

    if url != "" do
      cleaned_url = UrlCleaner.clean_url(url)
      url_display_info = UrlCleaner.get_display_urls(url)

      # Detect website type and adapter
      website_type = FocusedContentExtractor.detect_website_type(url)
      website_adapter = FocusedContentExtractor.get_website_adapter(website_type)

      {:noreply, assign(socket,
        url: url,
        cleaned_url: cleaned_url,
        url_display_info: url_display_info,
        website_type: website_type,
        website_adapter: website_adapter
      )}
    else
      {:noreply, assign(socket,
        url: url,
        cleaned_url: "",
        url_display_info: nil,
        website_type: nil,
        website_adapter: nil
      )}
    end
  end

  @impl true
  def handle_event("run_test", %{"url" => url, "crawler" => crawler_str}, socket) do
    url = String.trim(url)

    if url == "" do
      {:noreply, assign(socket, error: "Please enter a URL")}
    else
      cleaned_url = UrlCleaner.clean_url(url)
      url_display_info = UrlCleaner.get_display_urls(url)

      socket = assign(socket,
        cleaned_url: cleaned_url,
        url_display_info: url_display_info,
        loading: true,
        error: nil,
        product_data: nil,
        quality_info: nil,
        formatted_data: nil,
        job_id: nil,
        job_status: nil,
        debug_info: nil,
        raw_prompt: nil,
        raw_response: nil,
        extracted_html_data: nil,
        parsing_error: nil
      )

      result = case crawler_str do
        "traditional" ->
          # Use PlatformCrawler to detect website type and use appropriate crawler
          PlatformCrawler.crawl_product_fresh(url)

        "gemini" ->
          AiCrawler.crawl_product(url, :gemini)

        "grok" ->
          AiCrawler.crawl_product(url, :grok)

        "openrouter" ->
          AiCrawler.crawl_product(url, :openrouter)

        _ ->
          {:error, "Unknown crawler type: #{crawler_str}"}
      end

      case result do
        {:ok, {data, debug_info}} ->
          # Debug: Log the data structure being passed to quality assessment
          IO.puts("=== QUALITY ASSESSMENT DEBUG ===")
          IO.puts("Data keys: #{inspect(Map.keys(data))}")
          IO.puts("Images field: #{inspect(Map.get(data, :images))}")
          IO.puts("ImageUrls field: #{inspect(Map.get(data, :imageUrls))}")
          IO.puts("=== END DEBUG ===")

          quality = ResponseParser.validate_response_quality(data, "")
          formatted = format_detailed_result(data, quality)

          socket =
            socket
            |> assign(product_data: data)
            |> assign(quality_info: quality)
            |> assign(formatted_data: formatted)
            |> assign(debug_info: debug_info)
            |> assign(raw_prompt: debug_info[:prompt_sent])
            |> assign(raw_response: debug_info[:raw_response])
            |> assign(extracted_html_data: debug_info[:extracted_html_data])
            |> assign(loading: false)

          {:noreply, socket}

        {:ok, data} ->
          # Handle legacy format (traditional crawler)
          quality = ResponseParser.validate_response_quality(data, "")
          formatted = format_detailed_result(data, quality)

          socket =
            socket
            |> assign(product_data: data)
            |> assign(quality_info: quality)
            |> assign(formatted_data: formatted)
            |> assign(loading: false)

          {:noreply, socket}

        {:error, {reason, debug_info}} ->
          socket =
            socket
            |> assign(error: "Extraction failed: #{inspect(reason)}")
            |> assign(debug_info: debug_info)
            |> assign(raw_prompt: debug_info[:prompt_sent])
            |> assign(raw_response: debug_info[:raw_response])
            |> assign(extracted_html_data: debug_info[:extracted_html_data])
            |> assign(parsing_error: debug_info[:parsing_error])
            |> assign(loading: false)

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, assign(socket, error: "Extraction failed: #{inspect(reason)}", loading: false)}

        # For Oban async (if enabled):
        # {:ok, %Oban.Job{id: job_id}} ->
        #   {:noreply, assign(socket, job_id: job_id, job_status: "queued", loading: false)}
      end
    end
  end

  defp format_detailed_result(data, quality) do
    # Handle different dimension formats
    dimensions = case data do
      %{dimensions: %{length: _, width: _, height: _, unit: _} = dims} -> dims
      %{dimensionsStructured: %{length: _, width: _, height: _, unit: _} = dims} -> dims
      %{dimensions: dim_str} when is_binary(dim_str) ->
        # Parse string dimensions like "135.0cm × 135.0cm × 135.0cm"
        case Regex.run(~r/(\d+\.?\d*)\s*cm\s*×\s*(\d+\.?\d*)\s*cm\s*×\s*(\d+\.?\d*)\s*cm/, dim_str) do
          [_, l, w, h] -> %{length: parse_number(l), width: parse_number(w), height: parse_number(h), unit: "cm"}
          _ -> %{length: 0.0, width: 0.0, height: 0.0, unit: "mm"}
        end
      _ -> %{length: 0.0, width: 0.0, height: 0.0, unit: "mm"}
    end
    dim_str = "#{dimensions.length} x #{dimensions.width} x #{dimensions.height} #{dimensions.unit}"

    # Get images from different possible fields
    images = case data do
      %{images: imgs} when is_list(imgs) -> imgs
      %{imageUrls: imgs} when is_list(imgs) -> imgs
      _ -> []
    end

    %{
      title: Map.get(data, :title) || Map.get(data, :name) || "N/A",
      dimensions_str: dim_str,
      images: images,
      quality_score: quality.quality_score,
      issues: quality.issues || [],
      suggestions: quality.suggestions || [],
      is_acceptable: quality.is_acceptable,
      extracted_at: Map.get(data, :extracted_at) || Map.get(data, :scraped_at) || DateTime.utc_now(),
      crawler_type: Map.get(data, :crawler_type) || "traditional",
      ai_provider: Map.get(data, :ai_provider) || "traditional"
    }
  end

  defp mask_api_key(key) when is_binary(key) and byte_size(key) > 4 do
    "***" <> String.slice(key, -4..-1)
  end
  defp mask_api_key(_), do: "Not configured"


  # For Oban job updates (if using async):
  # def handle_info({:job_update, job_id, status, result}, socket) do
  #   if job_id == socket.assigns.job_id do
  #     case status do
  #       "completed" ->
  #         data = fetch_job_result(job_id)
  #         quality = ResponseParser.validate_response_quality(data, "")
  #         formatted = format_detailed_result(data, quality)
  #         assign(socket, job_status: "completed", product_data: data, quality_info: quality, formatted_data: formatted)
  #       "failed" ->
  #         assign(socket, job_status: "failed", error: result)
  #       _ ->
  #         assign(socket, job_status: status)
  #     end
  #   else
  #     {:noreply, socket}
  #   end
  # end
end
