defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.GenericAdapter do
  @moduledoc """
  Generic adapter for unknown websites.

  Uses common HTML patterns and selectors to extract content.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  @doc """
  Extracts product title using generic selectors.
  """
  def extract_title(document) do
    title_selectors = [
      "h1",
      ".product-title",
      ".product-name",
      ".title",
      ".name",
      "[data-testid*='title']",
      "[data-testid*='name']",
      ".product-header h1",
      ".product-info h1"
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
  Extracts dimension-related sections using generic patterns.
  """
  def extract_dimension_sections(document) do
    generic_selectors = %{
      tables: [
        "table tr",
        ".specifications tr",
        ".details tr",
        ".product-specs tr",
        ".product-details tr"
      ],
      bullets: [
        ".features li",
        ".specifications li",
        ".details li",
        ".product-features li",
        ".product-specs li"
      ],
      technical: [
        ".specifications",
        ".details",
        ".product-specs",
        ".product-details",
        ".technical-specs"
      ],
      description: [
        ".description p",
        ".product-description p",
        ".product-details p",
        ".specifications p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, generic_selectors)
  end

  @doc """
  Extracts product images using generic patterns.
  """
  def extract_images(document) do
    generic_selectors = %{
      main_images: [
        ".product-image img",
        ".main-image img",
        ".primary-image img",
        ".product-photo img",
        ".product-gallery img",
        "img[alt*='product']",
        "img[alt*='main']"
      ],
      gallery_images: [
        ".gallery img",
        ".thumbnails img",
        ".image-gallery img",
        ".product-gallery img",
        ".carousel img"
      ],
      hd_images: [
        "img[src*='large']",
        "img[src*='hd']",
        "img[src*='high']",
        "img[data-src*='large']"
      ]
    }

    BaseAdapter.extract_images_default(document, generic_selectors)
  end

  @doc """
  Extracts product context using generic patterns.
  """
  def extract_product_context(document) do
    generic_selectors = %{
      context: [
        ".description",
        ".product-description",
        ".product-details",
        ".product-info",
        ".specifications",
        ".features"
      ]
    }

    BaseAdapter.extract_product_context_default(document, generic_selectors)
  end
end
