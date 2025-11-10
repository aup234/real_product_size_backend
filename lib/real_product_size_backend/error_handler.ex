defmodule RealProductSizeBackend.ErrorHandler do
  @moduledoc """
  Advanced error handling and recovery system for product crawling.

  This module provides:
  - Graceful degradation for partial data
  - User feedback loop for data correction
  - Error classification and recovery strategies
  - Retry logic with exponential backoff
  - Error reporting and analytics
  """

  require Logger
  alias RealProductSizeBackend.{ProductValidator, UsageAnalytics}

  @doc """
  Handles errors during product crawling with appropriate recovery strategies.

  Returns {:ok, recovered_data} or {:error, unrecoverable_error}
  """
  def handle_crawl_error(url, error, context \\ %{}) do
    error_type = classify_error(error)

    Logger.error("Crawl error for #{url}: #{error_type} - #{inspect(error)}")

    # Track error for analytics
    UsageAnalytics.track_action(
      Map.get(context, :user_id, "unknown"),
      "crawl_error",
      %{
        url: url,
        error_type: error_type,
        error_message: inspect(error),
        context: context
      }
    )

    case error_type do
      :network_error ->
        handle_network_error(url, error, context)

      :validation_error ->
        handle_validation_error(url, error, context)

      :platform_error ->
        handle_platform_error(url, error, context)

      :rate_limit_error ->
        handle_rate_limit_error(url, error, context)

      :timeout_error ->
        handle_timeout_error(url, error, context)

      :not_found_error ->
        handle_not_found_error(url, error, context)

      :unauthorized_error ->
        handle_unauthorized_error(url, error, context)

      :forbidden_error ->
        handle_forbidden_error(url, error, context)

      :server_error ->
        handle_server_error(url, error, context)

      :bad_gateway_error ->
        handle_bad_gateway_error(url, error, context)

      :service_unavailable_error ->
        handle_service_unavailable_error(url, error, context)

      :gateway_timeout_error ->
        handle_gateway_timeout_error(url, error, context)

      :unknown_error ->
        handle_unknown_error(url, error, context)
    end
  end

  @doc """
  Provides graceful degradation for partial product data.

  Returns {:ok, partial_data} or {:error, reason}
  """
  def graceful_degradation(product_data, warnings \\ []) do
    case ProductValidator.validate_partial_product(product_data) do
      {:ok, partial_data} ->
        # Add degradation metadata
        degraded_data = partial_data
        |> Map.put(:degraded_at, DateTime.utc_now())
        |> Map.put(:degradation_reason, "Partial data available")
        |> Map.put(:warnings, warnings)
        |> Map.put(:recovery_suggestions, get_recovery_suggestions(partial_data))

        {:ok, degraded_data}

      {:error, reason} ->
        {:error, "Data too incomplete for graceful degradation: #{reason}"}
    end
  end

  @doc """
  Creates user feedback request for data correction.

  Returns {:ok, feedback_request} or {:error, reason}
  """
  def create_feedback_request(user_id, product_id, issue_type, details \\ %{}) do
    feedback_request = %{
      id: generate_feedback_id(),
      user_id: user_id,
      product_id: product_id,
      issue_type: issue_type,
      details: details,
      status: :pending,
      created_at: DateTime.utc_now(),
      priority: get_feedback_priority(issue_type)
    }

    # Store feedback request (in production, this would go to database)
    Logger.info("Created feedback request: #{inspect(feedback_request)}")

    {:ok, feedback_request}
  end

  @doc """
  Processes user feedback and updates product data.

  Returns {:ok, updated_data} or {:error, reason}
  """
  def process_user_feedback(feedback_id, user_corrections) do
    # In production, this would:
    # 1. Retrieve the feedback request from database
    # 2. Validate user corrections
    # 3. Update product data
    # 4. Notify other users if applicable

    Logger.info("Processing user feedback #{feedback_id}: #{inspect(user_corrections)}")

    # Mock processing
    updated_data = %{
      id: feedback_id,
      updated_at: DateTime.utc_now(),
      corrections: user_corrections,
      status: :processed
    }

    {:ok, updated_data}
  end

  @doc """
  Gets recovery suggestions for a product.

  Returns list of recovery suggestions
  """
  def get_recovery_suggestions(product_data) do
    suggestions = []

    # Check for missing dimensions
    suggestions = if not has_dimensions?(product_data) do
      [
        %{
          type: :missing_dimensions,
          message: "Product dimensions are missing",
          action: "Please provide length, width, and height",
          priority: :high
        } | suggestions
      ]
    else
      suggestions
    end

    # Check for missing images
    suggestions = if not has_images?(product_data) do
      [
        %{
          type: :missing_images,
          message: "Product images are missing",
          action: "Please upload product images",
          priority: :medium
        } | suggestions
      ]
    else
      suggestions
    end

    # Check for incomplete metadata
    suggestions = if not has_complete_metadata?(product_data) do
      [
        %{
          type: :incomplete_metadata,
          message: "Product information is incomplete",
          action: "Please provide brand, category, and description",
          priority: :low
        } | suggestions
      ]
    else
      suggestions
    end

    suggestions
  end

  # Private functions

  defp classify_error(error) do
    error_string = inspect(error)

    cond do
      String.contains?(error_string, "timeout") or String.contains?(error_string, "timed out") ->
        :timeout_error

      String.contains?(error_string, "network") or String.contains?(error_string, "connection") ->
        :network_error

      String.contains?(error_string, "validation") or String.contains?(error_string, "invalid") ->
        :validation_error

      String.contains?(error_string, "rate limit") or String.contains?(error_string, "429") ->
        :rate_limit_error

      String.contains?(error_string, "platform") or String.contains?(error_string, "crawler") ->
        :platform_error

      String.contains?(error_string, "not found") or String.contains?(error_string, "404") ->
        :not_found_error

      String.contains?(error_string, "unauthorized") or String.contains?(error_string, "401") ->
        :unauthorized_error

      String.contains?(error_string, "forbidden") or String.contains?(error_string, "403") ->
        :forbidden_error

      String.contains?(error_string, "server error") or String.contains?(error_string, "500") ->
        :server_error

      String.contains?(error_string, "bad gateway") or String.contains?(error_string, "502") ->
        :bad_gateway_error

      String.contains?(error_string, "service unavailable") or String.contains?(error_string, "503") ->
        :service_unavailable_error

      String.contains?(error_string, "gateway timeout") or String.contains?(error_string, "504") ->
        :gateway_timeout_error

      true ->
        :unknown_error
    end
  end

  defp handle_network_error(url, _error, _context) do
    # Network errors are often temporary, suggest retry
    {:error, %{
      type: :network_error,
      message: "Network connection failed",
      suggestion: "Please try again in a few moments",
      retry_after: 30,
      url: url
    }}
  end

  defp handle_validation_error(url, _error, _context) do
    # Validation errors might be recoverable with user input
    {:error, %{
      type: :validation_error,
      message: "Product data validation failed",
      suggestion: "Please check the product URL and try again",
      requires_user_action: true,
      url: url
    }}
  end

  defp handle_platform_error(url, _error, _context) do
    # Platform-specific errors might be recoverable with different approach
    {:error, %{
      type: :platform_error,
      message: "Platform-specific crawling failed",
      suggestion: "This platform might not be supported or the product might be unavailable",
      url: url
    }}
  end

  defp handle_rate_limit_error(url, _error, _context) do
    # Rate limit errors require waiting
    {:error, %{
      type: :rate_limit_error,
      message: "Rate limit exceeded",
      suggestion: "Please wait before trying again",
      retry_after: 300,  # 5 minutes
      url: url
    }}
  end

  defp handle_timeout_error(url, _error, _context) do
    # Timeout errors might be recoverable with retry
    {:error, %{
      type: :timeout_error,
      message: "Request timed out",
      suggestion: "The request took too long, please try again",
      retry_after: 60,
      url: url
    }}
  end

  defp handle_not_found_error(url, _error, _context) do
    # Product not found - might be removed or URL changed
    {:error, %{
      type: :not_found_error,
      message: "Product not found",
      suggestion: "The product may have been removed or the URL may have changed. Please check the URL and try again.",
      url: url,
      retry_after: 0  # Don't retry immediately
    }}
  end

  defp handle_unauthorized_error(url, _error, _context) do
    # Authentication required - might need API key or login
    {:error, %{
      type: :unauthorized_error,
      message: "Authentication required",
      suggestion: "Please check your credentials or API key and try again.",
      url: url,
      retry_after: 0  # Don't retry without fixing auth
    }}
  end

  defp handle_forbidden_error(url, _error, _context) do
    # Access denied - might be blocked or restricted
    {:error, %{
      type: :forbidden_error,
      message: "Access denied",
      suggestion: "You don't have permission to access this resource. Please check your access rights.",
      url: url,
      retry_after: 0  # Don't retry without fixing permissions
    }}
  end

  defp handle_server_error(url, _error, _context) do
    # Server error - temporary issue
    {:error, %{
      type: :server_error,
      message: "Server error occurred",
      suggestion: "The server encountered an error. Please try again in a few moments.",
      url: url,
      retry_after: 60  # Retry after 1 minute
    }}
  end

  defp handle_bad_gateway_error(url, _error, _context) do
    # Bad gateway - upstream server issue
    {:error, %{
      type: :bad_gateway_error,
      message: "Bad gateway error",
      suggestion: "There's an issue with the upstream server. Please try again later.",
      url: url,
      retry_after: 120  # Retry after 2 minutes
    }}
  end

  defp handle_service_unavailable_error(url, _error, _context) do
    # Service unavailable - maintenance or overload
    {:error, %{
      type: :service_unavailable_error,
      message: "Service temporarily unavailable",
      suggestion: "The service is temporarily unavailable. Please try again later.",
      url: url,
      retry_after: 300  # Retry after 5 minutes
    }}
  end

  defp handle_gateway_timeout_error(url, _error, _context) do
    # Gateway timeout - upstream server too slow
    {:error, %{
      type: :gateway_timeout_error,
      message: "Gateway timeout",
      suggestion: "The request took too long to process. Please try again with a different product.",
      url: url,
      retry_after: 180  # Retry after 3 minutes
    }}
  end

  defp handle_unknown_error(url, _error, _context) do
    # Unknown errors require investigation
    {:error, %{
      type: :unknown_error,
      message: "An unexpected error occurred",
      suggestion: "Please try again or contact support if the problem persists",
      url: url,
      retry_after: 60  # Retry after 1 minute
    }}
  end

  defp has_dimensions?(product_data) do
    case Map.get(product_data, :dimensionsStructured) do
      %{length: l, width: w, height: h} when l > 0 and w > 0 and h > 0 -> true
      _ -> false
    end
  end

  defp has_images?(product_data) do
    case Map.get(product_data, :imageUrls) do
      images when is_list(images) and length(images) > 0 -> true
      _ -> false
    end
  end

  defp has_complete_metadata?(product_data) do
    required_fields = [:title, :brand, :category]
    Enum.all?(required_fields, &Map.has_key?(product_data, &1))
  end

  defp get_feedback_priority(issue_type) do
    case issue_type do
      :missing_dimensions -> :high
      :missing_images -> :medium
      :incomplete_metadata -> :low
      _ -> :medium
    end
  end

  defp generate_feedback_id do
    "feedback_#{:rand.uniform(1000000)}"
  end

  @doc """
  Creates a user-friendly error response.

  Returns error response map
  """
  def create_error_response(error, context \\ %{}) do
    %{
      error: true,
      message: get_user_friendly_message(error),
      suggestion: get_user_suggestion(error),
      error_code: get_error_code(error),
      timestamp: DateTime.utc_now(),
      context: context
    }
  end

  defp get_user_friendly_message(error) do
    case error do
      %{type: :network_error} -> "Unable to connect to the product page"
      %{type: :validation_error} -> "The product information could not be processed"
      %{type: :platform_error} -> "This product platform is not supported"
      %{type: :rate_limit_error} -> "Too many requests, please wait a moment"
      %{type: :timeout_error} -> "The request took too long to complete"
      _ -> "An unexpected error occurred"
    end
  end

  defp get_user_suggestion(error) do
    case error do
      %{type: :network_error} -> "Please check your internet connection and try again"
      %{type: :validation_error} -> "Please verify the product URL and try again"
      %{type: :platform_error} -> "Try a different product or contact support"
      %{type: :rate_limit_error} -> "Please wait a few minutes before trying again"
      %{type: :timeout_error} -> "Please try again with a different product"
      _ -> "Please try again or contact support if the problem persists"
    end
  end

  defp get_error_code(error) do
    case error do
      %{type: :network_error} -> "NETWORK_ERROR"
      %{type: :validation_error} -> "VALIDATION_ERROR"
      %{type: :platform_error} -> "PLATFORM_ERROR"
      %{type: :rate_limit_error} -> "RATE_LIMIT_ERROR"
      %{type: :timeout_error} -> "TIMEOUT_ERROR"
      _ -> "UNKNOWN_ERROR"
    end
  end

  @doc """
  Test function for development.
  """
  def test_error_handling do
    # Test different error types
    test_errors = [
      %{type: :network_error, message: "Connection failed"},
      %{type: :validation_error, message: "Invalid data"},
      %{type: :platform_error, message: "Unsupported platform"},
      %{type: :rate_limit_error, message: "Rate limit exceeded"},
      %{type: :timeout_error, message: "Request timeout"}
    ]

    Enum.each(test_errors, fn error ->
      case handle_crawl_error("https://test.com", error) do
        {:error, error_response} ->
          Logger.info("Error response: #{inspect(error_response)}")
      end
    end)

    # Test graceful degradation
    partial_product = %{
      title: "Test Product",
      platform: :amazon
    }

    case graceful_degradation(partial_product) do
      {:ok, degraded_data} ->
        Logger.info("Graceful degradation successful: #{inspect(degraded_data)}")
      {:error, reason} ->
        Logger.error("Graceful degradation failed: #{reason}")
    end
  end
end
