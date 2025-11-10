defmodule RealProductSizeBackend.DimensionExtractionTest do
  @moduledoc """
  Test module for dimension extraction functionality.
  This module provides test functions to verify both crawler and AI extraction methods.
  """

  require Logger
  alias RealProductSizeBackend.AmazonCrawler
  alias RealProductSizeBackend.AiDimensionService

  @doc """
  Tests the complete dimension extraction workflow.
  """
  def test_dimension_extraction do
    Logger.info("=== Testing Dimension Extraction ===")

    # Test 1: Traditional crawler extraction
    test_crawler_extraction()

    # Test 2: AI extraction
    test_ai_extraction()

    # Test 3: Combined approach
    test_combined_extraction()

    Logger.info("=== Dimension Extraction Tests Complete ===")
  end

  @doc """
  Tests traditional crawler dimension extraction.
  """
  def test_crawler_extraction do
    Logger.info("Testing Traditional Crawler Extraction...")

    # Test with sample HTML that contains dimensions
    sample_html = """
    <html>
      <body>
        <table>
          <tr>
            <td>Dimensions</td>
            <td>10.2 x 5.1 x 2.3 inches</td>
          </tr>
          <tr>
            <td>Brand</td>
            <td>TestBrand</td>
          </tr>
        </table>
        <div id="feature-bullets">
          <span class="a-list-item">Product dimensions: 25.9 x 13 x 6.1 cm</span>
        </div>
      </body>
    </html>
    """

    case Floki.parse_document(sample_html) do
      {:ok, document} ->
        dimensions = AmazonCrawler.extract_dimensions_crawler(document)
        Logger.info("Crawler extracted dimensions: #{inspect(dimensions)}")

        case dimensions do
          %{length_mm: l, width_mm: w, height_mm: h}
          when is_number(l) and is_number(w) and is_number(h) ->
            Logger.info("✅ Crawler extraction successful: #{l} x #{w} x #{h} mm")

          _ ->
            Logger.warning("❌ Crawler extraction failed or returned invalid data")
        end

      {:error, reason} ->
        Logger.error("Failed to parse test HTML: #{reason}")
    end
  end

  @doc """
  Tests AI dimension extraction.
  """
  def test_ai_extraction do
    Logger.info("Testing AI Dimension Extraction...")

    # Test with sample product data
    test_document = %{
      title: "Test Product - Wireless Headphones",
      description:
        "High-quality wireless headphones with noise cancellation, dimensions: 180 x 80 x 25 mm",
      brand: "TestBrand"
    }

    case AiDimensionService.call_ai_dimension_extraction(test_document) do
      {:ok, ai_response} ->
        Logger.info("AI API response: #{ai_response}")

        case AiDimensionService.parse_ai_dimension_response(ai_response) do
          {:ok, dimensions} ->
            Logger.info("✅ AI extraction successful: #{inspect(dimensions)}")

          {:error, reason} ->
            Logger.warning("❌ AI response parsing failed: #{reason}")
        end

      {:error, reason} ->
        Logger.warning("❌ AI API call failed: #{reason}")
    end
  end

  @doc """
  Tests the combined extraction approach.
  """
  def test_combined_extraction do
    Logger.info("Testing Combined Extraction Approach...")

    # Test with sample HTML
    sample_html = """
    <html>
      <body>
        <h1 id="productTitle">Test Product</h1>
        <div id="feature-bullets">
          <span class="a-list-item">Great product with amazing features</span>
        </div>
        <div id="productDescription">
          <p>This is a test product description.</p>
        </div>
      </body>
    </html>
    """

    case Floki.parse_document(sample_html) do
      {:ok, document} ->
        dimensions = AmazonCrawler.extract_dimensions(document)
        Logger.info("Combined extraction result: #{inspect(dimensions)}")

        case dimensions do
          %{length_mm: l, width_mm: w, height_mm: h}
          when is_number(l) and is_number(w) and is_number(h) ->
            Logger.info("✅ Combined extraction successful: #{l} x #{w} x #{h} mm")

          _ ->
            Logger.warning("❌ Combined extraction failed or returned invalid data")
        end

      {:error, reason} ->
        Logger.error("Failed to parse test HTML: #{reason}")
    end
  end

  @doc """
  Tests dimension parsing with various formats.
  """
  def test_dimension_parsing do
    Logger.info("Testing Dimension Parsing...")

    test_cases = [
      "10.2 x 5.1 x 2.3 inches",
      "25.9 x 13 x 6.1 cm",
      "180 x 80 x 25 mm",
      "Length: 10.2, Width: 5.1, Height: 2.3",
      "10.2cm x 5.1cm x 2.3cm",
      "No dimensions found"
    ]

    Enum.each(test_cases, fn test_case ->
      Logger.info("Testing: #{test_case}")

      case AmazonCrawler.parse_dimensions_text(test_case) do
        %{length_mm: l, width_mm: w, height_mm: h}
        when is_number(l) and is_number(w) and is_number(h) ->
          Logger.info("✅ Parsed: #{l} x #{w} x #{h} mm")

        nil ->
          Logger.info("ℹ️  No dimensions parsed (expected for some cases)")

        _ ->
          Logger.warning("❌ Unexpected parsing result")
      end
    end)
  end

  @doc """
  Tests unit conversion functionality.
  """
  def test_unit_conversion do
    Logger.info("Testing Unit Conversion...")

    test_cases = [
      # 10 cm = 100 mm
      {10.0, "cm", 100.0},
      # 5 inches = 127 mm
      {5.0, "in", 127.0},
      # 25 mm = 25 mm
      {25.0, "mm", 25.0},
      # 2.5 inches = 63.5 mm
      {2.5, "inches", 63.5}
    ]

    Enum.each(test_cases, fn {value, unit, expected_mm} ->
      result = AmazonCrawler.convert_to_mm(value, unit)
      Logger.info("#{value} #{unit} = #{result} mm (expected: #{expected_mm})")

      if abs(result - expected_mm) < 0.1 do
        Logger.info("✅ Conversion correct")
      else
        Logger.warning("❌ Conversion incorrect")
      end
    end)
  end

  @doc """
  Runs all dimension extraction tests.
  """
  def run_all_tests do
    Logger.info("🚀 Starting Dimension Extraction Tests...")

    test_dimension_parsing()
    test_unit_conversion()
    test_crawler_extraction()
    test_ai_extraction()
    test_combined_extraction()

    Logger.info("🎉 All tests completed!")
  end
end
