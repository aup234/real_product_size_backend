defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.OverstockAdapter do
  @moduledoc """
  Overstock-specific adapter for content extraction.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  def extract_title(document) do
    title_selectors = [
      ".product-title",
      "h1.product-title",
      ".product-name",
      "h1.product-name"
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
    overstock_selectors = %{
      tables: [
        ".product-specifications tr",
        ".specifications tr",
        ".details tr"
      ],
      bullets: [
        ".product-specifications li",
        ".specifications li",
        ".details li"
      ],
      technical: [
        ".product-specifications",
        ".specifications",
        ".details"
      ],
      description: [
        ".product-specifications p",
        ".specifications p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, overstock_selectors)
  end

  def extract_images(document) do
    overstock_selectors = %{
      main_images: [
        ".product-image img",
        ".main-image img",
        ".gallery img"
      ],
      gallery_images: [
        ".gallery img",
        ".thumbnails img"
      ],
      hd_images: [
        "img[src*='overstock']",
        "img[data-src*='overstock']"
      ]
    }

    BaseAdapter.extract_images_default(document, overstock_selectors)
  end

  def extract_product_context(document) do
    overstock_selectors = %{
      context: [
        ".product-specifications",
        ".specifications",
        ".details",
        ".description"
      ]
    }

    BaseAdapter.extract_product_context_default(document, overstock_selectors)
  end
end
