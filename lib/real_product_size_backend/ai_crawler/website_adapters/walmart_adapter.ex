defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.WalmartAdapter do
  @moduledoc """
  Walmart-specific adapter for content extraction.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  def extract_title(document) do
    title_selectors = [
      "[data-automation-id='product-title']",
      ".prod-ProductTitle",
      "h1.prod-ProductTitle",
      ".product-title"
    ]

    title_selectors
    |> Enum.find_value(fn selector ->
      case Floki.find(document, selector) do
        [] -> nil
        [element | _] ->
          Floki.text(element)
          |> String.trim()
          |> case do
            "" -> nil
            title -> title
          end
      end
    end)
  end

  def extract_dimension_sections(document) do
    walmart_selectors = %{
      tables: [
        ".prod-ProductDetails tr",
        ".prod-Specifications tr",
        ".prod-Details tr"
      ],
      bullets: [
        ".prod-ProductDetails li",
        ".prod-Specifications li",
        ".prod-Details li"
      ],
      technical: [
        ".prod-ProductDetails",
        ".prod-Specifications",
        ".prod-Details"
      ],
      description: [
        ".prod-ProductDetails p",
        ".prod-Specifications p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, walmart_selectors)
  end

  def extract_images(document) do
    walmart_selectors = %{
      main_images: [
        ".prod-ProductImage img",
        ".prod-MainImage img",
        ".prod-Gallery img"
      ],
      gallery_images: [
        ".prod-Gallery img",
        ".prod-Thumbnails img"
      ],
      hd_images: [
        "img[src*='walmart']",
        "img[data-src*='walmart']"
      ]
    }

    BaseAdapter.extract_images_default(document, walmart_selectors)
  end

  def extract_product_context(document) do
    walmart_selectors = %{
      context: [
        ".prod-ProductDetails",
        ".prod-Specifications",
        ".prod-Details",
        ".prod-Description"
      ]
    }

    BaseAdapter.extract_product_context_default(document, walmart_selectors)
  end
end
