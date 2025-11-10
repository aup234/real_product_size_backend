defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.MujiAdapter do
  @moduledoc """
  Muji-specific adapter for content extraction.

  Handles Muji's online shops in USA, Japan, and Hong Kong.
  Supports both English and Japanese content.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  @doc """
  Extracts product title from Muji page.
  """
  def extract_title(document) do
    title_selectors = [
      # Muji USA selectors
      ".product-title",
      ".product-name",
      "h1.product-title",
      "h1.product-name",
      ".product-detail-title",
      ".product-info h1",

      # Muji Japan selectors
      ".productTitle",
      ".productName",
      "h1.productTitle",
      "h1.productName",
      ".product-detail-title",
      ".product-info h1",

      # Muji Hong Kong selectors
      ".product-title",
      ".product-name",
      "h1.product-title",
      "h1.product-name",
      ".product-detail-title",
      ".product-info h1",

      # Generic Muji selectors
      "[data-testid*='title']",
      "[data-testid*='name']",
      ".product-header h1",
      ".product-info h1",
      ".item-title",
      ".item-name"
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
  Extracts dimension-related sections from Muji page.
  """
  def extract_dimension_sections(document) do
    muji_selectors = %{
      tables: [
        # Muji USA tables
        ".product-specifications tr",
        ".product-details tr",
        ".specifications tr",
        ".product-info tr",
        ".product-specs tr",

        # Muji Japan tables
        ".productSpecifications tr",
        ".productDetails tr",
        ".specifications tr",
        ".productInfo tr",
        ".productSpecs tr",

        # Muji Hong Kong tables
        ".product-specifications tr",
        ".product-details tr",
        ".specifications tr",
        ".product-info tr",
        ".product-specs tr",

        # Generic tables
        "table tr",
        ".specs tr",
        ".details tr"
      ],
      bullets: [
        # Muji USA bullets
        ".product-features li",
        ".product-specifications li",
        ".product-details li",
        ".specifications li",
        ".product-info li",

        # Muji Japan bullets
        ".productFeatures li",
        ".productSpecifications li",
        ".productDetails li",
        ".specifications li",
        ".productInfo li",

        # Muji Hong Kong bullets
        ".product-features li",
        ".product-specifications li",
        ".product-details li",
        ".specifications li",
        ".product-info li",

        # Generic bullets
        ".features li",
        ".specifications li",
        ".details li"
      ],
      technical: [
        # Muji USA technical sections
        ".product-specifications",
        ".product-details",
        ".specifications",
        ".product-info",
        ".product-specs",

        # Muji Japan technical sections
        ".productSpecifications",
        ".productDetails",
        ".specifications",
        ".productInfo",
        ".productSpecs",

        # Muji Hong Kong technical sections
        ".product-specifications",
        ".product-details",
        ".specifications",
        ".product-info",
        ".product-specs",

        # Generic technical sections
        ".specifications",
        ".details",
        ".technical-specs"
      ],
      description: [
        # Muji USA descriptions
        ".product-description p",
        ".product-details p",
        ".specifications p",
        ".product-info p",

        # Muji Japan descriptions
        ".productDescription p",
        ".productDetails p",
        ".specifications p",
        ".productInfo p",

        # Muji Hong Kong descriptions
        ".product-description p",
        ".product-details p",
        ".specifications p",
        ".product-info p",

        # Generic descriptions
        ".description p",
        ".product-description p",
        ".product-details p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, muji_selectors)
  end

  @doc """
  Extracts product images from Muji page.
  """
  def extract_images(document) do
    muji_selectors = %{
      main_images: [
        # Muji USA main images
        ".product-image img",
        ".product-photo img",
        ".main-image img",
        ".product-gallery img",
        ".product-images img",

        # Muji Japan main images
        ".productImage img",
        ".productPhoto img",
        ".mainImage img",
        ".productGallery img",
        ".productImages img",

        # Muji Hong Kong main images
        ".product-image img",
        ".product-photo img",
        ".main-image img",
        ".product-gallery img",
        ".product-images img",

        # Generic Muji images
        ".product-image img",
        ".main-image img",
        ".product-gallery img",
        "img[alt*='product']",
        "img[alt*='main']",
        "img[src*='muji']",
        "img[src*='product']"
      ],
      gallery_images: [
        # Muji USA gallery
        ".product-gallery img",
        ".thumbnails img",
        ".image-gallery img",
        ".product-images img",
        ".gallery img",

        # Muji Japan gallery
        ".productGallery img",
        ".thumbnails img",
        ".imageGallery img",
        ".productImages img",
        ".gallery img",

        # Muji Hong Kong gallery
        ".product-gallery img",
        ".thumbnails img",
        ".image-gallery img",
        ".product-images img",
        ".gallery img",

        # Generic gallery
        ".gallery img",
        ".thumbnails img",
        ".image-gallery img",
        ".carousel img"
      ],
      hd_images: [
        # High-resolution Muji images
        "img[src*='large']",
        "img[src*='hd']",
        "img[src*='high']",
        "img[src*='original']",
        "img[data-src*='large']",
        "img[data-src*='hd']",
        "img[data-src*='high']",
        "img[data-src*='original']",

        # Muji-specific HD patterns
        "img[src*='muji']",
        "img[src*='product']",
        "img[data-src*='muji']",
        "img[data-src*='product']"
      ]
    }

    BaseAdapter.extract_images_default(document, muji_selectors)
  end

  @doc """
  Extracts product context from Muji page.
  """
  def extract_product_context(document) do
    muji_selectors = %{
      context: [
        # Muji USA context
        ".product-description",
        ".product-details",
        ".product-info",
        ".specifications",
        ".product-features",
        ".product-specs",

        # Muji Japan context
        ".productDescription",
        ".productDetails",
        ".productInfo",
        ".specifications",
        ".productFeatures",
        ".productSpecs",

        # Muji Hong Kong context
        ".product-description",
        ".product-details",
        ".product-info",
        ".specifications",
        ".product-features",
        ".product-specs",

        # Generic Muji context
        ".description",
        ".product-description",
        ".product-details",
        ".product-info",
        ".specifications",
        ".features"
      ]
    }

    BaseAdapter.extract_product_context_default(document, muji_selectors)
  end
end
