defmodule RealProductSizeBackend.AiDimensionService do
  @moduledoc """
  AI-powered dimension extraction service using Gemini and Grok APIs.
  """

  require Logger
  alias RealProductSizeBackend.AmazonCrawler

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

  @doc """
  Extracts product dimensions using AI analysis.
  Falls back to traditional crawling if AI fails.
  """
  def extract_dimensions_with_ai(document) do
    # Check if AI extraction is enabled
    if Application.get_env(:real_product_size_backend, :ai_extraction, :enabled) == :enabled do
      case call_ai_dimension_extraction(document) do
        {:ok, dimensions} ->
          Logger.info("Successfully extracted dimensions via AI: #{inspect(dimensions)}")
          dimensions

        {:error, reason} ->
          Logger.warning("AI dimension extraction failed: #{reason}")
          # Fallback to traditional crawling
          Logger.info("Falling back to traditional crawling")
          AmazonCrawler.extract_dimensions_crawler(document)
      end
    else
      Logger.info("AI extraction disabled, using traditional crawling")
      AmazonCrawler.extract_dimensions_crawler(document)
    end
  end

  @doc """
  Calls AI API to extract dimensions from product information.
  """
  def call_ai_dimension_extraction(document) do
    # Extract relevant text for AI analysis
    product_text = extract_product_text_for_ai(document)

    # Choose AI provider based on configuration
    ai_provider = Application.get_env(:real_product_size_backend, :ai_provider, :gemini)

    case ai_provider do
      :gemini -> call_gemini_api(product_text)
      :grok -> call_grok_api(product_text)
      :openrouter -> call_openrouter_api(product_text)
      _ -> {:error, "Unsupported AI provider: #{ai_provider}"}
    end
  end

  @doc """
  Extracts relevant product text for AI analysis.
  """
  def extract_product_text_for_ai(document) do
    # Extract key product information for AI analysis
    title = AmazonCrawler.extract_title(document) || ""
    description = AmazonCrawler.extract_description(document) || ""
    brand = AmazonCrawler.extract_brand(document) || ""

    # Combine relevant text
    """
    Product Title: #{title}
    Brand: #{brand}
    Description: #{description}

    Please extract the product dimensions (length, width, height) from this information.
    Return the dimensions in millimeters (mm) in the format: L x W x H mm
    If dimensions are not available, return "No dimensions found".

    Focus on finding:
    1. Product dimensions in any unit (convert to mm)
    2. Package dimensions if product dimensions not available
    3. Size specifications in the description
    4. Any measurement information

    Return only the dimensions in the format: L x W x H mm
    """
  end

  @doc """
  Calls Gemini API for dimension extraction.
  """
  def call_gemini_api(product_text) do
    api_key = Application.get_env(:real_product_size_backend, :gemini_api_key)

    if is_nil(api_key) do
      {:error, "Gemini API key not configured"}
    else
      # Gemini API call implementation
      Logger.info("Calling Gemini API for dimension extraction")

      # TODO: Replace with actual Gemini API client
      # For now, using mock response
      mock_gemini_response(product_text)
    end
  end

  @doc """
  Calls Grok API for dimension extraction.
  """
  def call_grok_api(product_text) do
    api_key = Application.get_env(:real_product_size_backend, :grok_api_key)

    if is_nil(api_key) do
      {:error, "Grok API key not configured"}
    else
      # Grok API call implementation
      Logger.info("Calling Grok API for dimension extraction")

      # TODO: Replace with actual Grok API client
      # For now, using mock response
      mock_grok_response(product_text)
    end
  end

  def call_openrouter_api(product_text) do
    api_key = Application.get_env(:real_product_size_backend, :openrouter_api_key)

    if is_nil(api_key) do
      {:error, "OpenRouter API key not configured"}
    else
      # OpenRouter API call implementation
      Logger.info("Calling OpenRouter API for dimension extraction")

      # TODO: Replace with actual OpenRouter API client
      # For now, using mock response
      mock_openrouter_response(product_text)
    end
  end

  @doc """
  Parses AI response and converts to structured dimension data.
  """
  def parse_ai_dimension_response(response) when is_binary(response) do
    # Parse AI response like "180 x 80 x 25 mm" or "No dimensions found"
    case response do
      "No dimensions found" ->
        {:error, "No dimensions found by AI"}

      response when is_binary(response) ->
        # Try to parse dimension format
        case parse_dimension_format(response) do
          {:ok, dimensions} -> {:ok, dimensions}
          {:error, reason} -> {:error, "Failed to parse AI response: #{reason}"}
        end

      _ ->
        {:error, "Invalid AI response format"}
    end
  end

  def parse_ai_dimension_response(_), do: {:error, "Invalid response type"}

  @doc """
  Parses dimension format from AI response.
  """
  def parse_dimension_format(text) do
    # Multiple patterns for AI responses
    patterns = [
      # Standard format: "L x W x H mm"
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*mm/i,

      # Format with units: "L x W x H cm" (convert to mm)
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*cm/i,

      # Format with inches: "L x W x H inches" (convert to mm)
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*in(?:ches)?/i,

      # Format without units: "L x W x H" (assume mm)
      ~r/(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)/i
    ]

    # Try each pattern
    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [_, l, w, h, unit] ->
          {:ok,
           %{
             length_mm: convert_to_mm(parse_number(l), unit),
             width_mm: convert_to_mm(parse_number(w), unit),
             height_mm: convert_to_mm(parse_number(h), unit),
             unit: unit,
             confidence: 0.95,
             source: "ai"
           }}

        [_, l, w, h] ->
          # Assume mm if no unit specified
          {:ok,
           %{
             length_mm: parse_number(l),
             width_mm: parse_number(w),
             height_mm: parse_number(h),
             unit: "mm",
             confidence: 0.9,
             source: "ai"
           }}

        _ ->
          nil
      end
    end) || {:error, "No dimension pattern matched"}
  end

  @doc """
  Converts dimensions to millimeters.
  """
  def convert_to_mm(value, unit) when is_number(value) do
    case String.downcase(unit) do
      "mm" -> value
      "cm" -> value * 10.0
      "in" -> value * 25.4
      "inch" -> value * 25.4
      "inches" -> value * 25.4
      # Default to cm
      _ -> value * 10.0
    end
  end

  # Mock responses for development/testing
  defp mock_gemini_response(product_text) do
    Logger.info("Mock Gemini API call with text: #{String.slice(product_text, 0, 100)}...")

    # Simulate different responses based on product type
    cond do
      String.contains?(product_text, "headphone") ->
        {:ok, "180 x 80 x 25 mm"}

      String.contains?(product_text, "coffee") ->
        {:ok, "300 x 200 x 400 mm"}

      String.contains?(product_text, "laptop") ->
        {:ok, "250 x 200 x 150 mm"}

      String.contains?(product_text, "yoga") ->
        {:ok, "1830 x 610 x 6 mm"}

      true ->
        {:ok, "100 x 50 x 25 mm"}
    end
  end

  defp mock_grok_response(product_text) do
    Logger.info("Mock Grok API call with text: #{String.slice(product_text, 0, 100)}...")

    # Simulate different responses based on product type
    cond do
      String.contains?(product_text, "headphone") ->
        {:ok, "175 x 78 x 23 mm"}

      String.contains?(product_text, "coffee") ->
        {:ok, "305 x 198 x 395 mm"}

      String.contains?(product_text, "laptop") ->
        {:ok, "248 x 202 x 148 mm"}

      String.contains?(product_text, "yoga") ->
        {:ok, "1825 x 615 x 5 mm"}

      true ->
        {:ok, "102 x 48 x 26 mm"}
    end
  end

  defp mock_openrouter_response(product_text) do
    Logger.info("Mock OpenRouter API call with text: #{String.slice(product_text, 0, 100)}...")

    # Simulate different responses based on product type
    cond do
      String.contains?(product_text, "headphone") ->
        {:ok, "177 x 79 x 24 mm"}

      String.contains?(product_text, "coffee") ->
        {:ok, "302 x 199 x 397 mm"}

      String.contains?(product_text, "laptop") ->
        {:ok, "249 x 201 x 149 mm"}

      String.contains?(product_text, "yoga") ->
        {:ok, "1828 x 613 x 5.5 mm"}

      true ->
        {:ok, "101 x 49 x 25.5 mm"}
    end
  end

  @doc """
  Test function for development.
  """
  def test_ai_extraction do
    test_document = %{
      title: "Test Product - Wireless Headphones",
      description: "High-quality wireless headphones with noise cancellation",
      brand: "TestBrand"
    }

    Logger.info("Testing AI dimension extraction...")
    result = call_ai_dimension_extraction(test_document)
    Logger.info("AI extraction result: #{inspect(result)}")
    result
  end
end
