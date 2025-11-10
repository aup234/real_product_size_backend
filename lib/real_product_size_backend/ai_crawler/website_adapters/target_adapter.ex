defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.TargetAdapter do
  @moduledoc """
  Target-specific adapter for content extraction.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  def extract_title(document) do
    title_selectors = [
      "[data-test='product-title']",
      ".styles__ProductTitle",
      "h1[data-test='product-title']",
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
    target_selectors = %{
      tables: [
        ".styles__Specifications tr",
        ".styles__Details tr",
        ".styles__ProductDetails tr"
      ],
      bullets: [
        ".styles__Specifications li",
        ".styles__Details li",
        ".styles__ProductDetails li"
      ],
      technical: [
        ".styles__Specifications",
        ".styles__Details",
        ".styles__ProductDetails"
      ],
      description: [
        ".styles__Specifications p",
        ".styles__Details p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, target_selectors)
  end

  def extract_images(document) do
    target_selectors = %{
      main_images: [
        ".styles__ProductImage img",
        ".styles__MainImage img",
        ".styles__Gallery img"
      ],
      gallery_images: [
        ".styles__Gallery img",
        ".styles__Thumbnails img"
      ],
      hd_images: [
        "img[src*='target']",
        "img[data-src*='target']"
      ]
    }

    BaseAdapter.extract_images_default(document, target_selectors)
  end

  def extract_product_context(document) do
    target_selectors = %{
      context: [
        ".styles__Specifications",
        ".styles__Details",
        ".styles__ProductDetails",
        ".styles__Description"
      ]
    }

    BaseAdapter.extract_product_context_default(document, target_selectors)
  end
end
