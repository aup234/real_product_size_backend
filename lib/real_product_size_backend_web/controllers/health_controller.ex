defmodule RealProductSizeBackendWeb.HealthController do
  use RealProductSizeBackendWeb, :controller

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
  Health check endpoint for monitoring and testing
  """
  def health(conn, _params) do
    # Check database connectivity
    db_status = check_database_health()

    # Check external services
    external_services = check_external_services()

    # Check system resources
    system_health = check_system_health()

    # Overall health status
    overall_status = determine_overall_status(db_status, external_services, system_health)

    health_data = %{
      status: overall_status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.get_env(:real_product_size_backend, :version, "1.0.0"),
      environment: Application.get_env(:real_product_size_backend, :environment, "development"),
      services: %{
        database: db_status,
        external: external_services,
        system: system_health
      },
      uptime: get_uptime(),
      memory_usage: get_memory_usage(),
      active_connections: get_active_connections()
    }

    status_code = if overall_status == "healthy", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(health_data)
  end

  defp check_database_health do
    try do
      # Test database connection
      RealProductSizeBackend.Repo.query!("SELECT 1")
      %{status: "healthy", response_time_ms: 0}
    rescue
      error ->
        %{status: "unhealthy", error: Exception.message(error)}
    end
  end

  defp check_external_services do
    %{
      gemini_api: check_service_health("gemini"),
      grok_api: check_service_health("grok"),
      openrouter_api: check_service_health("openrouter"),
      tripo_api: check_service_health("tripo"),
      amazon_api: check_service_health("amazon"),
      ikea_api: check_service_health("ikea")
    }
  end

  defp check_service_health(service) do
    case service do
      "gemini" ->
        case Application.get_env(:real_product_size_backend, :gemini_api_key) do
          nil -> %{status: "not_configured"}
          _key -> %{status: "configured"}
        end
      "grok" ->
        case Application.get_env(:real_product_size_backend, :grok_api_key) do
          nil -> %{status: "not_configured"}
          _key -> %{status: "configured"}
        end
      "openrouter" ->
        case Application.get_env(:real_product_size_backend, :openrouter_api_key) do
          nil -> %{status: "not_configured"}
          _key -> %{status: "configured"}
        end
      "tripo" ->
        case Application.get_env(:real_product_size_backend, :tripo) do
          nil -> %{status: "not_configured"}
          config ->
            if config[:api_key] do
              %{status: "configured"}
            else
              %{status: "not_configured"}
            end
        end
      _ ->
        %{status: "unknown"}
    end
  end

  defp check_system_health do
    %{
      memory_usage: get_memory_usage(),
      process_count: get_process_count(),
      load_average: get_load_average()
    }
  end

  defp determine_overall_status(db_status, external_services, _system_health) do
    # Database must be healthy
    if db_status[:status] != "healthy" do
      "unhealthy"
    else
      # Check if critical external services are configured
      critical_services = [:gemini_api, :tripo_api]
      critical_configured =
        critical_services
        |> Enum.all?(fn service ->
          case Map.get(external_services, service) do
            %{status: "configured"} -> true
            _ -> false
          end
        end)

      if critical_configured do
        "healthy"
      else
        "degraded"
      end
    end
  end

  defp get_uptime do
    # Get system uptime in seconds
    case :os.cmd(~c"uptime") do
      uptime_str when is_binary(uptime_str) ->
        # Parse uptime from system command
        uptime_str
        |> String.trim()
        |> String.split(" ")
        |> List.last()
        |> String.replace("load average:", "")
        |> String.trim()
      _ ->
        "unknown"
    end
  end

  defp get_memory_usage do
    # Get memory usage information
    case :erlang.memory() do
      memory_info when is_list(memory_info) ->
        total = :erlang.memory(:total)
        processes = :erlang.memory(:processes)
        system = :erlang.memory(:system)

        %{
          total_mb: round(total / 1024 / 1024),
          processes_mb: round(processes / 1024 / 1024),
          system_mb: round(system / 1024 / 1024),
          usage_percentage: round((processes + system) / total * 100)
        }
      _ ->
        %{error: "unable_to_get_memory_info"}
    end
  end

  defp get_active_connections do
    # Get number of active Phoenix connections
    case Process.whereis(RealProductSizeBackendWeb.Endpoint) do
      nil -> 0
      _pid ->
        # This is a simplified approach - in production you'd want more sophisticated tracking
        :erlang.system_info(:process_count)
    end
  end

  defp get_process_count do
    :erlang.system_info(:process_count)
  end

  defp get_load_average do
    # Get system load average
    case :os.cmd(~c"uptime") do
      uptime_str when is_binary(uptime_str) ->
        # Extract load average from uptime output
        case Regex.run(~r/load average: ([\d.]+), ([\d.]+), ([\d.]+)/, uptime_str) do
          [_, load1, load5, load15] ->
            %{
              load_1min: parse_number(load1),
              load_5min: parse_number(load5),
              load_15min: parse_number(load15)
            }
          _ ->
            %{error: "unable_to_parse_load_average"}
        end
      _ ->
        %{error: "unable_to_get_load_average"}
    end
  end
end
