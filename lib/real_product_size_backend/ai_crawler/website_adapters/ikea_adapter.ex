defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.IkeaAdapter do
  @moduledoc """
  IKEA-specific adapter for content extraction.

  Handles IKEA's specific HTML structure and selectors.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  @doc """
  Extracts product title from IKEA page.
  """
  def extract_title(document) do
    title_selectors = [
      "h1[data-testid='product-title']",
      ".pip-product-name",
      ".product-title",
      "h1.pip-header-section__title"
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

  @doc """
  Extracts dimension-related sections from IKEA page.
  """
  def extract_dimension_sections(document) do
    ikea_selectors = %{
      tables: [
        ".pip-product-details tr",
        ".pip-dimensions tr",
        ".pip-specifications tr",
        ".pip-product-specifications tr"
      ],
      bullets: [
        ".pip-product-details li",
        ".pip-dimensions li",
        ".pip-specifications li"
      ],
      technical: [
        ".pip-product-details",
        ".pip-dimensions",
        ".pip-specifications",
        ".pip-product-specifications"
      ],
      description: [
        ".pip-product-details p",
        ".pip-dimensions p",
        ".pip-specifications p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, ikea_selectors)
  end

  @doc """
  Extracts product images from IKEA page.
  """
  def extract_images(document) do
    ikea_selectors = %{
      main_images: [
        ".pip-media img",
        ".pip-image img",
        ".pip-product-image img",
        ".pip-main-image img"
      ],
      gallery_images: [
        ".pip-media-gallery img",
        ".pip-thumbnails img",
        ".pip-image-gallery img"
      ],
      hd_images: [
        "img[src*='ikea']",
        "img[data-src*='ikea']"
      ]
    }

    BaseAdapter.extract_images_default(document, ikea_selectors)
  end

  @doc """
  Extracts product context from IKEA page.
  """
  def extract_product_context(document) do
    ikea_selectors = %{
      context: [
        ".pip-product-details",
        ".pip-dimensions",
        ".pip-specifications",
        ".pip-product-description",
        ".pip-product-info"
      ]
    }

    BaseAdapter.extract_product_context_default(document, ikea_selectors)
  end
end
