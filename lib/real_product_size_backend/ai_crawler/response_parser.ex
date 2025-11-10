defmodule RealProductSizeBackend.AiCrawler.ResponseParser do
  @moduledoc """
  AI response parser and validator for product data extraction.

  Supports both legacy string responses and new structured map responses from Instructor.
  """

  require Logger

  @doc """
  Parses AI response and extracts product data.

  Handles both string (JSON) and map (structured) inputs.
  """
  def parse_product_data(ai_response) when is_binary(ai_response) do
    # Legacy: clean and parse JSON
    cleaned_response = clean_ai_response(ai_response)

    case Jason.decode(cleaned_response) do
      {:ok, product_data} ->
        validate_product_data(product_data)

      {:error, reason} ->
        {:error, "Failed to parse JSON response: #{inspect(reason)}"}
    end
  end

  def parse_product_data(product_data) when is_map(product_data) do
    # New structured: validate the map directly
    validate_product_data(product_data)
  end

  def parse_product_data(_), do: {:error, "Invalid response type"}

  defp validate_product_data(data) when is_map(data) do
    with :ok <- validate_required_fields(data),
         :ok <- validate_data_types(data),
         :ok <- validate_dimensions(data),
         :ok <- validate_price_format(data) do
      {:ok, normalize_product_data(data)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_required_fields(data) do
    required_fields = [:title, :price]

    missing_fields =
      required_fields
      |> Enum.reject(&Map.has_key?(data, &1))

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_data_types(data) do
    type_validations = [
      {:title, :is_binary, "Title must be a string"},
      {:price, :is_binary, "Price must be a string"},
      {:rating, :is_binary_or_nil, "Rating must be a string or null"},
      {:description, :is_binary_or_nil, "Description must be a string or null"},
      {:brand, :is_binary_or_nil, "Brand must be a string or null"},
      {:material, :is_binary_or_nil, "Material must be a string or null"},
      {:images, :is_list_or_nil, "Images must be a list or null"},
      {:availability, :is_binary_or_nil, "Availability must be a string or null"}
    ]

    Enum.find_value(type_validations, fn {field, validator_type, error_msg} ->
      case Map.get(data, field) do
        nil -> nil
        value ->
          if validate_field_type(value, validator_type) do
            nil
          else
            {:error, error_msg}
          end
      end
    end) || :ok
  end

  defp validate_field_type(value, :is_binary), do: is_binary(value)
  defp validate_field_type(value, :is_binary_or_nil), do: is_binary(value) or is_nil(value)
  defp validate_field_type(value, :is_list_or_nil), do: is_list(value) or is_nil(value)

  defp validate_dimensions(data) do
    case Map.get(data, :dimensions) do
      nil -> :ok
      dimensions when is_map(dimensions) -> validate_dimension_structure(dimensions)
      _ -> {:error, "Dimensions must be a map or null"}
    end
  end

  defp validate_dimension_structure(dimensions) do
    # Check if all dimension values are null - if so, that's valid
    numeric_fields = [:length, :width, :height]
    all_numeric_null = Enum.all?(numeric_fields, fn field ->
      case Map.get(dimensions, field) do
        nil -> true
        _ -> false
      end
    end)

    if all_numeric_null do
      :ok
    else
      # If some dimensions are provided, validate them
      required_dim_fields = [:length, :width, :height, :unit]

      missing_fields =
        required_dim_fields
        |> Enum.reject(&Map.has_key?(dimensions, &1))

      if Enum.empty?(missing_fields) do
        invalid_numeric =
          numeric_fields
          |> Enum.find(fn field ->
            case Map.get(dimensions, field) do
              value when is_number(value) and value >= 0 -> false
              nil -> false  # Allow null values
              _ -> true
            end
          end)

        if invalid_numeric do
          {:error, "Dimension #{invalid_numeric} must be a non-negative number"}
        else
          :ok
        end
      else
        {:error, "Missing dimension fields: #{Enum.join(missing_fields, ", ")}"}
      end
    end
  end

  defp validate_price_format(data) do
    case Map.get(data, :price) do
      nil -> :ok
      price when is_binary(price) ->
        if String.match?(price, ~r/[\$¥€£]\s*\d+/) or String.match?(price, ~r/\d+[\$¥€£]/) do
          :ok
        else
          {:error, "Price format is invalid. Expected format like '$19.99' or '¥1,234'"}
        end
      _ -> :ok
    end
  end

  defp normalize_product_data(data) do
    data
    |> normalize_strings()
    |> normalize_dimensions()
    |> normalize_images()
    |> add_default_values()
  end

  defp normalize_strings(data) do
    string_fields = [
      :title, :price, :rating, :description, :brand, :material, :availability, :category, :weight, :color, :size
    ]

    Enum.reduce(string_fields, data, fn field, acc ->
      case Map.get(acc, field) do
        nil -> acc
        value when is_binary(value) -> Map.put(acc, field, String.trim(value))
        _ -> acc
      end
    end)
  end

  defp normalize_dimensions(data) do
    case Map.get(data, :dimensions) do
      nil -> data
      dimensions when is_map(dimensions) ->
        normalized_dims =
          dimensions
          |> Map.update(:length, 0.0, &ensure_float/1)
          |> Map.update(:width, 0.0, &ensure_float/1)
          |> Map.update(:height, 0.0, &ensure_float/1)
          |> Map.update(:unit, "mm", &ensure_string/1)

        Map.put(data, :dimensions, normalized_dims)
      _ -> data
    end
  end

  defp normalize_images(data) do
    case Map.get(data, :images) do
      nil -> Map.put(data, :images, [])
      images when is_list(images) ->
        valid_images =
          images
          |> Enum.filter(&is_binary/1)
          |> Enum.filter(&String.starts_with?(&1, "http"))
          |> Enum.take(10)

        Map.put(data, :images, valid_images)
      _ -> Map.put(data, :images, [])
    end
  end

  defp add_default_values(data) do
    defaults = %{
      images: [],
      dimensions: %{
        length: 0.0,
        width: 0.0,
        height: 0.0,
        unit: "mm"
      },
      crawler_type: "ai",
      extracted_at: DateTime.utc_now()
    }

    Map.merge(defaults, data)
  end

  defp ensure_float(value) when is_number(value), do: value
  defp ensure_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp ensure_float(_), do: 0.0

  defp ensure_string(value) when is_binary(value), do: value
  defp ensure_string(value) when is_atom(value), do: Atom.to_string(value)
  defp ensure_string(_), do: "mm"

  # Legacy cleaning functions for string responses
  def clean_ai_response(response) do
    response
    |> String.trim()
    |> remove_markdown_code_blocks()
    |> extract_json_from_text()
    |> normalize_json_format()
  end

  defp remove_markdown_code_blocks(text) do
    text
    |> String.replace(~r/```json\s*/, "")
    |> String.replace(~r/```\s*$/, "")
    |> String.replace(~r/^```\s*/, "")
  end

  defp extract_json_from_text(text) do
    case Regex.run(~r/\{[\s\S]*\}/, text) do
      [json_part] -> json_part
      nil -> text
    end
  end

  defp normalize_json_format(json_string) do
    json_string
    |> String.replace(~r/""(https?:\/\/[^"]*?)""/, "\"\\1\"")
    |> String.replace(~r/,\s*}/, "}")
    |> String.replace(~r/,\s*]/, "]")
    |> String.replace(~r/(\w+):/, "\"\\1\":")
    |> String.replace(~r/:\s*'([^']*)'/, ": \"\\1\"")
  end

  @doc """
  Parses dimension-specific AI response.
  """
  def parse_dimension_response(ai_response) do
    case parse_product_data(ai_response) do
      {:ok, %{dimensions: dimensions}} when is_map(dimensions) ->
        {:ok, dimensions}

      {:ok, _} ->
        {:error, "No dimensions found in response"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses price-specific AI response.
  """
  def parse_price_response(ai_response) do
    case parse_product_data(ai_response) do
      {:ok, %{price: price}} when is_binary(price) ->
        {:ok, %{price: price}}

      {:ok, _} ->
        {:error, "No price found in response"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates AI response quality and provides feedback.
  """
  def validate_response_quality(extracted_data, original_html) do
    quality_score = calculate_quality_score(extracted_data)
    issues = identify_quality_issues(extracted_data, original_html)

    %{
      quality_score: quality_score,
      issues: issues,
      is_acceptable: quality_score >= 0.7,
      suggestions: generate_improvement_suggestions(issues)
    }
  end

  defp calculate_quality_score(data) do
    total_fields = 10

    present_fields =
      data
      |> Map.keys()
      |> Enum.count(fn key ->
        case Map.get(data, key) do
          nil -> false
          "" -> false
          [] -> false
          _ -> true
        end
      end)

    base_score = present_fields / total_fields

    critical_bonus =
      if Map.has_key?(data, :title) and Map.has_key?(data, :price), do: 0.2, else: 0

    min(1.0, base_score + critical_bonus)
  end

  defp identify_quality_issues(data, _original_html) do
    issues = []

    issues =
      if is_nil(Map.get(data, :title)) or Map.get(data, :title) == "",
        do: ["Missing product title"] ++ issues,
        else: issues

    issues =
      if is_nil(Map.get(data, :price)) or Map.get(data, :price) == "",
        do: ["Missing product price"] ++ issues,
        else: issues

    # Check for images in multiple possible fields
    images = Map.get(data, :images) || Map.get(data, :imageUrls) || []
    issues =
      if length(images) == 0,
        do: ["No product images found"] ++ issues,
        else: issues

    case Map.get(data, :dimensions) do
      %{length: 0, width: 0, height: 0} -> ["No valid dimensions found"] ++ issues
      nil -> ["Missing dimension information"] ++ issues
      _ -> issues
    end
  end

  defp generate_improvement_suggestions(issues) do
    Enum.map(issues, fn issue ->
      case issue do
        "Missing product title" -> "Try extracting from h1 tags or product title selectors"
        "Missing product price" -> "Look for price in .a-price-whole or similar selectors"
        "No product images found" -> "Check for img tags with product images"
        "No valid dimensions found" -> "Search in product details table or specifications"
        _ -> "Review HTML structure and extraction logic"
      end
    end)
  end
end
