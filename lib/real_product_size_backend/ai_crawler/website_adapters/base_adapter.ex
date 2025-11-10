defmodule RealProductSizeBackend.AiCrawler.WebsiteAdapters.BaseAdapter do
  @moduledoc """
  Base adapter for website-specific content extraction.

  All website adapters should implement this behavior.
  """

  @callback extract_title(document :: any()) :: String.t() | nil
  @callback extract_dimension_sections(document :: any()) :: list(map())
  @callback extract_images(document :: any()) :: list(String.t())
  @callback extract_product_context(document :: any()) :: String.t() | nil

  @doc """
  Default implementation for dimension section extraction.
  """
  def extract_dimension_sections_default(document, selectors \\ %{}) do
    sections = []

    # Extract table rows with dimension keywords
    sections = sections ++ extract_dimension_table_rows(document, selectors)

    # Extract feature bullets with dimension keywords
    sections = sections ++ extract_dimension_bullets(document, selectors)

    # Extract technical details
    sections = sections ++ extract_technical_details_section(document, selectors)

    # Extract description parts
    sections = sections ++ extract_dimension_description_parts(document, selectors)

    # Clean and prioritize sections
    prioritize_dimension_sections(sections)
  end

  @doc """
  Default implementation for image extraction.
  """
  def extract_images_default(document, selectors \\ %{}) do
    images = []

    # Main product images
    main_image_selectors = selectors[:main_images] || ["img[src*='amazon']", ".product-image img", "#main-image img"]
    main_images = extract_images_by_selectors(document, main_image_selectors)
    images = images ++ main_images

    # Image gallery
    gallery_selectors = selectors[:gallery_images] || [".gallery img", ".thumbnails img", ".image-gallery img"]
    gallery_images = extract_images_by_selectors(document, gallery_selectors)
    images = images ++ gallery_images

    # High-resolution images
    hd_selectors = selectors[:hd_images] || ["img[src*='AC_SL']", "img[src*='AC_UL']", "img[data-src*='AC_SL']"]
    hd_images = extract_images_by_selectors(document, hd_selectors)
    images = images ++ hd_images

    # Remove duplicates and limit
    images
    |> Enum.uniq()
    |> Enum.take(5)
  end

  @doc """
  Default implementation for product context extraction.
  """
  def extract_product_context_default(document, selectors \\ %{}) do
    context_selectors = selectors[:context] || [
      ".product-description",
      ".product-details",
      ".product-info",
      "#productDescription",
      ".description"
    ]

    context_text = context_selectors
    |> Enum.map(fn selector ->
      Floki.find(document, selector)
      |> Floki.text()
      |> String.trim()
    end)
    |> Enum.filter(fn text -> String.length(text) > 10 end)
    |> Enum.join(" ")
    |> String.slice(0, 1000)

    if String.length(context_text) > 50, do: context_text, else: nil
  end

  # Private helper functions

  defp extract_dimension_table_rows(document, selectors) do
    table_selectors = selectors[:tables] || ["table tr", ".specs tr", ".details tr"]

    table_selectors
    |> Enum.flat_map(fn selector ->
      Floki.find(document, selector)
    end)
    |> Enum.filter(fn row ->
      text = Floki.text(row)
      dimension_keywords = [
        "dimension", "size", "measurement", "length", "width", "height",
        "寸法", "サイズ", "長さ", "幅", "高さ", "package", "product",
        "cm", "mm", "inch", "inches", "feet", "ft"
      ]

      Enum.any?(dimension_keywords, fn keyword ->
        String.contains?(String.downcase(text), keyword)
      end)
    end)
    |> Enum.map(fn row ->
      %{
        type: "table_row",
        content: Floki.text(row),
        priority: 1
      }
    end)
  end

  defp extract_dimension_bullets(document, selectors) do
    bullet_selectors = selectors[:bullets] || [
      "#feature-bullets .a-list-item",
      ".features li",
      ".specifications li",
      ".product-features li"
    ]

    bullet_selectors
    |> Enum.flat_map(fn selector ->
      Floki.find(document, selector)
    end)
    |> Enum.filter(fn bullet ->
      text = Floki.text(bullet)
      dimension_keywords = [
        "dimension", "size", "measurement", "length", "width", "height",
        "cm", "mm", "inch", "inches", "寸法", "サイズ"
      ]

      Enum.any?(dimension_keywords, fn keyword ->
        String.contains?(String.downcase(text), keyword)
      end)
    end)
    |> Enum.map(fn bullet ->
      %{
        type: "feature_bullet",
        content: Floki.text(bullet),
        priority: 2
      }
    end)
  end

  defp extract_technical_details_section(document, selectors) do
    tech_selectors = selectors[:technical] || [
      ".technical-details",
      ".specifications",
      ".product-specs",
      "#technical-details"
    ]

    tech_selectors
    |> Enum.flat_map(fn selector ->
      Floki.find(document, selector)
    end)
    |> Enum.map(fn section ->
      %{
        type: "technical_details",
        content: Floki.text(section),
        priority: 3
      }
    end)
  end

  defp extract_dimension_description_parts(document, selectors) do
    desc_selectors = selectors[:description] || [
      "#productDescription p",
      ".product-description p",
      ".description p"
    ]

    desc_selectors
    |> Enum.flat_map(fn selector ->
      Floki.find(document, selector)
    end)
    |> Enum.filter(fn paragraph ->
      text = Floki.text(paragraph)
      dimension_keywords = [
        "dimension", "size", "measurement", "length", "width", "height",
        "cm", "mm", "inch", "inches", "寸法", "サイズ"
      ]

      Enum.any?(dimension_keywords, fn keyword ->
        String.contains?(String.downcase(text), keyword)
      end)
    end)
    |> Enum.map(fn paragraph ->
      %{
        type: "description",
        content: Floki.text(paragraph),
        priority: 4
      }
    end)
  end

  defp extract_images_by_selectors(document, selectors) do
    selectors
    |> Enum.flat_map(fn selector ->
      Floki.find(document, selector)
      |> Floki.attribute("src")
    end)
    |> Enum.concat(
      selectors
      |> Enum.flat_map(fn selector ->
        Floki.find(document, selector)
        |> Floki.attribute("data-src")
      end)
    )
    |> Enum.filter(&RealProductSizeBackend.AiCrawler.FocusedContentExtractor.is_valid_product_image/1)
  end

  defp prioritize_dimension_sections(sections) do
    sections
    |> Enum.sort_by(fn section -> section.priority end)
    |> Enum.take(10)  # Limit to top 10 most relevant sections
  end
end
