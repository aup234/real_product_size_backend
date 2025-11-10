defmodule RealProductSizeBackend.ProductValidator do
  @moduledoc """
  Multi-layer validation system for product data and AR compatibility.

  This module provides comprehensive validation for:
  - Product data completeness and accuracy
  - AR visualization compatibility
  - Dimension validation and normalization
  - Image quality and availability
  - Metadata validation
  """

  require Logger

  @doc """
  Validates product data for AR compatibility and quality.

  Returns {:ok, validated_data} or {:error, validation_errors}
  """
  def validate_product_data(product_data) do
    validation_results = [
      validate_dimensions(product_data),
      validate_images(product_data),
      validate_metadata(product_data),
      validate_ar_compatibility(product_data),
      validate_quality_score(product_data)
    ]

    # Check if all validations passed
    errors = Enum.filter(validation_results, fn
      {:error, _} -> true
      _ -> false
    end)

    case errors do
      [] ->
        # All validations passed
        validated_data = enhance_product_data(product_data)
        {:ok, validated_data}

      errors ->
        # Some validations failed
        error_messages = Enum.map(errors, fn {:error, message} -> message end)
        {:error, %{validation_errors: error_messages, product_data: product_data}}
    end
  end

  @doc """
  Validates product dimensions for AR visualization.

  Returns {:ok, dimensions} or {:error, reason}
  """
  def validate_dimensions(product_data) do
    case product_data do
      %{dimensionsStructured: %{length: l, width: w, height: h}} when l > 0 and w > 0 and h > 0 ->
        # Validate dimension ranges
        cond do
          l > 10000 or w > 10000 or h > 10000 ->
            {:error, "Dimensions too large for AR visualization (max 10m)"}

          l < 1 or w < 1 or h < 1 ->
            {:error, "Dimensions too small for AR visualization (min 1mm)"}

          # Check for reasonable aspect ratios
          l / w > 50 or w / l > 50 or l / h > 50 or h / l > 50 or w / h > 50 or h / w > 50 ->
            {:error, "Unrealistic aspect ratios detected"}

          true ->
            # Normalize dimensions to ensure consistency
            normalized_dims = normalize_dimensions(%{length: l, width: w, height: h})
            {:ok, normalized_dims}
        end

      %{dimensionsStructured: %{length: l, width: w, height: h}} when l == 0 or w == 0 or h == 0 ->
        {:error, "Incomplete dimensions - some dimensions are zero"}

      _ ->
        {:error, "No valid dimensions found"}
    end
  end

  @doc """
  Validates product images for AR visualization.

  Returns {:ok, images} or {:error, reason}
  """
  def validate_images(product_data) do
    case product_data do
      %{imageUrls: images} when is_list(images) and length(images) > 0 ->
        # Validate image URLs
        valid_images = Enum.filter(images, &valid_image_url?/1)

        case valid_images do
          [] ->
            {:error, "No valid image URLs found"}

          valid_images when length(valid_images) >= 1 ->
            # Check image quality indicators
            quality_score = calculate_image_quality_score(valid_images)

            if quality_score >= 0.5 do
              {:ok, %{images: valid_images, quality_score: quality_score}}
            else
              {:error, "Image quality too low for AR visualization"}
            end

          _ ->
            {:error, "Insufficient valid images"}
        end

      _ ->
        {:error, "No images provided"}
    end
  end

  @doc """
  Validates product metadata for completeness.

  Returns {:ok, metadata} or {:error, reason}
  """
  def validate_metadata(product_data) do
    required_fields = [:title, :platform, :source_url]
    optional_fields = [:brand, :category, :description, :price, :materials, :colors]

    # Check required fields
    missing_required = Enum.filter(required_fields, fn field ->
      not Map.has_key?(product_data, field) or
      is_nil(product_data[field]) or
      (is_binary(product_data[field]) and String.trim(product_data[field]) == "")
    end)

    case missing_required do
      [] ->
        # All required fields present, validate optional fields
        validated_metadata = validate_optional_metadata(product_data, optional_fields)
        {:ok, validated_metadata}

      missing ->
        {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
    end
  end

  @doc """
  Validates AR compatibility of the product.

  Returns {:ok, compatibility} or {:error, reason}
  """
  def validate_ar_compatibility(product_data) do
    # Check if product is marked as AR suitable
    ar_suitable = Map.get(product_data, :ar_suitable, false)

    if not ar_suitable do
      {:error, "Product not suitable for AR visualization"}
    else
      # Additional AR compatibility checks
      compatibility_score = calculate_ar_compatibility_score(product_data)

      if compatibility_score >= 0.7 do
        {:ok, %{ar_compatible: true, compatibility_score: compatibility_score}}
      else
        {:error, "Product has low AR compatibility score: #{compatibility_score}"}
      end
    end
  end

  @doc """
  Validates overall quality score of the product data.

  Returns {:ok, quality} or {:error, reason}
  """
  def validate_quality_score(product_data) do
    quality_score = Map.get(product_data, :crawl_quality_score, 0.0)

    if quality_score >= 0.5 do
      {:ok, %{quality_score: quality_score, quality_level: get_quality_level(quality_score)}}
    else
      {:error, "Product data quality too low: #{quality_score}"}
    end
  end

  # Private functions

  defp normalize_dimensions(%{length: l, width: w, height: h}) do
    # Ensure dimensions are in millimeters
    %{
      length: Float.round(l, 1),
      width: Float.round(w, 1),
      height: Float.round(h, 1),
      unit: "mm"
    }
  end

  defp valid_image_url?(url) when is_binary(url) do
    # Basic URL validation
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        # Check for common image extensions
        String.ends_with?(String.downcase(url), [".jpg", ".jpeg", ".png", ".webp", ".gif"])
      _ ->
        false
    end
  end

  defp valid_image_url?(_), do: false

  defp calculate_image_quality_score(images) do
    # Simple quality scoring based on image count and URL patterns
    base_score = min(length(images) / 3.0, 1.0)  # More images = higher score

    # Bonus for high-resolution image indicators
    resolution_bonus = Enum.count(images, fn url ->
      String.contains?(url, ["high", "large", "hd", "4k"]) or
      String.contains?(url, ["_lg", "_xl", "_xxl"])
    end) / max(length(images), 1)

    min(1.0, base_score + resolution_bonus * 0.3)
  end

  defp validate_optional_metadata(product_data, optional_fields) do
    Enum.reduce(optional_fields, %{}, fn field, acc ->
      case Map.get(product_data, field) do
        nil -> acc
        value when is_binary(value) ->
          trimmed = String.trim(value)
          if trimmed != "" do
            Map.put(acc, field, trimmed)
          else
            acc
          end
        value when is_list(value) and length(value) > 0 ->
          Map.put(acc, field, value)
        _ -> acc
      end
    end)
  end

  defp calculate_ar_compatibility_score(product_data) do
    score = 0.0

    # Dimension availability (40% weight)
    score = if has_valid_dimensions?(product_data), do: score + 0.4, else: score

    # Image availability (30% weight)
    score = if has_valid_images?(product_data), do: score + 0.3, else: score

    # Product type suitability (20% weight)
    product_type = Map.get(product_data, :product_type, :general)
    score = if product_type in [:furniture, :home_garden, :electronics], do: score + 0.2, else: score

    # Metadata completeness (10% weight)
    score = if has_complete_metadata?(product_data), do: score + 0.1, else: score

    score
  end

  defp has_valid_dimensions?(product_data) do
    case Map.get(product_data, :dimensionsStructured) do
      %{length: l, width: w, height: h} when l > 0 and w > 0 and h > 0 -> true
      _ -> false
    end
  end

  defp has_valid_images?(product_data) do
    case Map.get(product_data, :imageUrls) do
      images when is_list(images) and length(images) > 0 -> true
      _ -> false
    end
  end

  defp has_complete_metadata?(product_data) do
    required_fields = [:title, :brand, :category]
    Enum.all?(required_fields, &Map.has_key?(product_data, &1))
  end

  defp get_quality_level(score) do
    cond do
      score >= 0.9 -> :excellent
      score >= 0.8 -> :very_good
      score >= 0.7 -> :good
      score >= 0.6 -> :fair
      score >= 0.5 -> :poor
      true -> :very_poor
    end
  end

  defp enhance_product_data(product_data) do
    # Add validation metadata
    product_data
    |> Map.put(:validated_at, DateTime.utc_now())
    |> Map.put(:validation_status, :passed)
    |> Map.put(:ar_ready, true)
  end

  @doc """
  Validates a product for partial data (graceful degradation).

  Returns {:ok, partial_data} with warnings or {:error, reason}
  """
  def validate_partial_product(product_data) do
    # More lenient validation for partial data
    warnings = []

    # Check dimensions
    dimensions_result = validate_dimensions(product_data)
    warnings = case dimensions_result do
      {:error, _} -> ["Missing or invalid dimensions" | warnings]
      _ -> warnings
    end

    # Check images
    images_result = validate_images(product_data)
    warnings = case images_result do
      {:error, _} -> ["Missing or invalid images" | warnings]
      _ -> warnings
    end

    # Check metadata
    metadata_result = validate_metadata(product_data)
    warnings = case metadata_result do
      {:error, _} -> ["Incomplete metadata" | warnings]
      _ -> warnings
    end

    # If we have at least title and some data, consider it valid with warnings
    if Map.has_key?(product_data, :title) and not is_nil(product_data.title) do
      enhanced_data = product_data
      |> Map.put(:validated_at, DateTime.utc_now())
      |> Map.put(:validation_status, :partial)
      |> Map.put(:warnings, warnings)
      |> Map.put(:ar_ready, length(warnings) <= 2)  # Allow AR if not too many issues

      {:ok, enhanced_data}
    else
      {:error, "Product data too incomplete for processing"}
    end
  end

  @doc """
  Gets validation summary for a product.

  Returns validation summary map
  """
  def get_validation_summary(product_data) do
    %{
      has_dimensions: has_valid_dimensions?(product_data),
      has_images: has_valid_images?(product_data),
      has_complete_metadata: has_complete_metadata?(product_data),
      ar_compatibility_score: calculate_ar_compatibility_score(product_data),
      quality_score: Map.get(product_data, :crawl_quality_score, 0.0),
      validation_status: Map.get(product_data, :validation_status, :not_validated),
      warnings: Map.get(product_data, :warnings, [])
    }
  end

  @doc """
  Test function for development.
  """
  def test_validation do
    # Test with complete product data
    complete_product = %{
      title: "Test Product",
      platform: :amazon,
      source_url: "https://amazon.com/dp/test",
      dimensionsStructured: %{length: 100.0, width: 50.0, height: 25.0},
      imageUrls: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"],
      brand: "Test Brand",
      category: "Electronics",
      ar_suitable: true,
      crawl_quality_score: 0.8
    }

    case validate_product_data(complete_product) do
      {:ok, validated_data} ->
        Logger.info("Complete product validation passed: #{validated_data.title}")
      {:error, errors} ->
        Logger.error("Complete product validation failed: #{inspect(errors)}")
    end

    # Test with partial product data
    partial_product = %{
      title: "Partial Product",
      platform: :amazon,
      source_url: "https://amazon.com/dp/partial"
    }

    case validate_partial_product(partial_product) do
      {:ok, validated_data} ->
        Logger.info("Partial product validation passed: #{validated_data.title}")
        Logger.info("Warnings: #{inspect(validated_data.warnings)}")
      {:error, errors} ->
        Logger.error("Partial product validation failed: #{inspect(errors)}")
    end
  end
end
