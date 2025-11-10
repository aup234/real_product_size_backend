defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.AmazonAdapter do
  @moduledoc """
  Amazon-specific adapter for content extraction.

  Handles Amazon's specific HTML structure and selectors.
  """

  @behaviour RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  alias RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter

  @doc """
  Extracts product title from Amazon page.
  """
  def extract_title(document) do
    title_selectors = [
      "#productTitle",
      ".product-title",
      "h1[data-automation-id='product-title']",
      ".a-size-large"
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
  Extracts dimension-related sections from Amazon page.
  """
  def extract_dimension_sections(document) do
    amazon_selectors = %{
      tables: [
        "table tr",
        "#productDetails_detailBullets_sections1 tr",
        "#productDetails_techSpec_section_1 tr",
        ".a-keyvalue tr"
      ],
      bullets: [
        "#feature-bullets .a-list-item",
        ".a-unordered-list .a-list-item"
      ],
      technical: [
        "#productDetails_techSpec_section_1",
        "#productDetails_detailBullets_sections1",
        ".a-section.a-spacing-medium"
      ],
      description: [
        "#productDescription p",
        "#productDescription_feature_div p",
        ".a-section.a-spacing-medium p"
      ]
    }

    BaseAdapter.extract_dimension_sections_default(document, amazon_selectors)
  end

  @doc """
  Extracts product images from Amazon page.
  """
  def extract_images(document) do
    amazon_selectors = %{
      main_images: [
        "#landingImage",
        "#imgTagWrapperId img",
        ".a-dynamic-image",
        "#main-image-container img"
      ],
      gallery_images: [
        "#altImages img",
        ".a-button-text img",
        ".a-carousel-card img",
        ".a-spacing-small img"
      ],
      hd_images: [
        "img[src*='AC_SL']",
        "img[src*='AC_UL']",
        "img[data-src*='AC_SL']",
        "img[data-src*='AC_UL']"
      ]
    }

    BaseAdapter.extract_images_default(document, amazon_selectors)
  end

  @doc """
  Extracts product context from Amazon page.
  """
  def extract_product_context(document) do
    amazon_selectors = %{
      context: [
        "#productDescription",
        "#productDescription_feature_div",
        ".a-section.a-spacing-medium",
        "#feature-bullets",
        ".a-unordered-list"
      ]
    }

    BaseAdapter.extract_product_context_default(document, amazon_selectors)
  end
end
