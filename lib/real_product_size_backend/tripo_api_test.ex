defmodule RealProductSizeBackend.TripoApiTest do
  @moduledoc """
  Simple test module to verify TripoAI API connectivity and endpoints
  """

  require Logger
  @finch_name :"RealProductSizeBackend.Finch"

  defp get_tripo_config do
    Application.get_env(:real_product_size_backend, :tripo, [])
  end

  @doc """
  Test basic connectivity to TripoAI API
  """
  def test_api_connectivity do
    api_url = get_tripo_config()[:api_url]
    api_key = get_tripo_config()[:api_key]

    Logger.info("Testing TripoAI API connectivity")
    Logger.info("API URL: #{api_url}")
    Logger.info("API Key: #{String.slice(api_key, 0, 10)}...")

    # Test basic endpoint
    test_urls = [
      "#{api_url}/v2/upload",
      "#{api_url}/v2/openapi/task",
      "#{api_url}/health"
    ]

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"User-Agent", "RealProductSizeBackend/1.0"}
    ]

    Enum.each(test_urls, fn url ->
      Logger.info("Testing URL: #{url}")

      case Finch.build(:get, url, headers)
           |> Finch.request(@finch_name, receive_timeout: 10_000) do
        {:ok, %{status: status, body: body}} ->
          Logger.info("✅ #{url} -> HTTP #{status}")
          if status in [200, 404, 401, 403] do
            Logger.debug("Response body: #{String.slice(body, 0, 200)}...")
          end

        {:ok, %{status: status, headers: headers}} ->
          Logger.warning("⚠️ #{url} -> HTTP #{status}")
          Logger.debug("Response headers: #{inspect(headers)}")

        {:error, reason} ->
          Logger.error("❌ #{url} -> Error: #{inspect(reason)}")
      end
    end)
  end

  @doc """
  Simple connectivity test - just check if we can reach the API
  """
  def test_simple_connectivity do
    api_url = get_tripo_config()[:api_url]
    api_key = get_tripo_config()[:api_key]

    Logger.info("=== Simple TripoAI Connectivity Test ===")
    Logger.info("API URL: #{api_url}")
    Logger.info("API Key: #{String.slice(api_key, 0, 15)}...")

    # Test basic connectivity with a simple GET request
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"User-Agent", "RealProductSizeBackend/1.0"},
      {"Accept", "application/json"}
    ]

    # Try different possible base endpoints
    test_endpoints = [
      "#{api_url}/",
      "#{api_url}/v2",
      "#{api_url}/api",
      "#{api_url}/api/v2",
      "#{api_url}/health",
      "#{api_url}/status"
    ]

    Enum.each(test_endpoints, fn endpoint ->
      Logger.info("Testing endpoint: #{endpoint}")

      case Finch.build(:get, endpoint, headers)
           |> Finch.request(@finch_name, receive_timeout: 10_000) do
        {:ok, %{status: status, body: body, headers: response_headers}} ->
          Logger.info("✅ #{endpoint} -> HTTP #{status}")

          # Log response details for successful connections
          if status == 200 do
            Logger.info("Response body preview: #{String.slice(body, 0, 100)}...")
            Logger.debug("Response headers: #{inspect(response_headers)}")
          end

          # Check for CORS headers which indicate API endpoints
          cors_headers = Enum.filter(response_headers, fn {k, _v} ->
            String.downcase(k) |> String.contains?("access-control")
          end)

          if length(cors_headers) > 0 do
            Logger.info("🔍 CORS headers detected - this might be an API endpoint")
            Logger.debug("CORS headers: #{inspect(cors_headers)}")
          end

        {:ok, %{status: status, headers: response_headers}} ->
          Logger.warning("⚠️ #{endpoint} -> HTTP #{status}")
          Logger.debug("Response headers: #{inspect(response_headers)}")

        {:error, reason} ->
          Logger.error("❌ #{endpoint} -> Error: #{inspect(reason)}")
      end
    end)

    Logger.info("=== End Simple Connectivity Test ===")
    :ok
  end

  @doc """
  Test API with a simple POST request
  """
  def test_api_post do
    api_url = get_tripo_config()[:api_url]
    api_key = get_tripo_config()[:api_key]

    url = "#{api_url}/v2/openapi/task"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "RealProductSizeBackend/1.0"}
    ]

    # Simple test payload
    test_payload = %{
      "prompt" => "test",
      "style" => "realistic"
    } |> Jason.encode!()

    Logger.info("Testing POST to: #{url}")
    Logger.debug("Payload: #{test_payload}")

    case Finch.build(:post, url, headers, test_payload)
         |> Finch.request(@finch_name, receive_timeout: 30_000) do
      {:ok, %{status: status, body: body}} ->
        Logger.info("POST Response: HTTP #{status}")
        Logger.info("Response body: #{body}")

        case status do
          200 -> Logger.info("✅ API is working correctly")
          400 -> Logger.warning("⚠️ Bad request - check payload format")
          401 -> Logger.error("❌ Authentication failed - check API key")
          403 -> Logger.error("❌ Forbidden - check API permissions")
          404 -> Logger.error("❌ Endpoint not found - check API URL")
          307 -> Logger.error("❌ Redirect - API endpoint may have changed")
          _ -> Logger.warning("⚠️ Unexpected status: #{status}")
        end

      {:error, reason} ->
        Logger.error("❌ POST request failed: #{inspect(reason)}")
    end
  end

  @doc """
  Extreme simple test for v2/openapi endpoint
  """
  def test_simple_v2_openapi do
    api_url = get_tripo_config()[:api_url]
    api_key = get_tripo_config()[:api_key]

    url = "#{api_url}/v2/openapi"

    Logger.info("=== EXTREME SIMPLE TEST ===")
    Logger.info("Testing URL: #{url}")
    Logger.info("API Key prefix: #{String.slice(api_key, 0, 10)}...")

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Accept", "application/json"},
      {"User-Agent", "RealProductSizeBackend/1.0"}
    ]

    case Finch.build(:get, url, headers)
         |> Finch.request(@finch_name, receive_timeout: 10_000) do
      {:ok, %{status: status, body: body, headers: response_headers}} ->
        Logger.info("Response Status: #{status}")
        Logger.info("Response Body: #{inspect(body, pretty: true)}")
        Logger.info("Response Headers: #{inspect(response_headers, pretty: true)}")

      {:error, reason} ->
        Logger.error("Error: #{inspect(reason, pretty: true)}")
    end

    Logger.info("=== TEST COMPLETE ===")
  end
end
