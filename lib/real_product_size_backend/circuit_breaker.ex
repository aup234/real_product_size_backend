defmodule RealProductSizeBackend.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern implementation for service resilience.

  This module provides circuit breaker functionality to prevent cascading failures
  and improve system resilience by temporarily stopping calls to failing services.
  """

  require Logger
  use GenServer

  @default_config %{
    failure_threshold: 5,        # Number of failures before opening circuit
    timeout: 60_000,             # Time in milliseconds to wait before trying again
    success_threshold: 3,        # Number of successes needed to close circuit
    max_failures: 10             # Maximum failures before permanent failure
  }

  # Client API

  def start_link({name, config}) do
    GenServer.start_link(__MODULE__, {name, config}, name: via_tuple(name))
  end

  def child_spec({name, config}) do
    %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [{name, config}]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def call_with_circuit_breaker(service_name, fun, fallback \\ nil) do
    case get_service_state(service_name) do
      :closed ->
        execute_with_fallback(fun, fallback)

      :open ->
        Logger.warning("Circuit breaker open for #{service_name}, using fallback")
        execute_fallback(fallback)

      :half_open ->
        attempt_recovery(service_name, fun, fallback)
    end
  end

  def get_service_state(service_name) do
    case GenServer.call(via_tuple(service_name), :get_state) do
      {:ok, state} -> state
      {:error, :not_found} -> :closed  # Default to closed if service not found
    end
  end

  def reset_circuit(service_name) do
    GenServer.call(via_tuple(service_name), :reset)
  end

  def get_circuit_stats(service_name) do
    GenServer.call(via_tuple(service_name), :get_stats)
  end

  # Server callbacks

  def init({name, config}) do
    state = %{
      name: name,
      config: Map.merge(@default_config, config),
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      total_requests: 0,
      total_failures: 0,
      total_successes: 0
    }

    {:ok, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state.state}, state}
  end

  def handle_call(:reset, _from, state) do
    new_state = %{state |
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil
    }
    Logger.info("Circuit breaker reset for #{state.name}")
    {:reply, :ok, new_state}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      service_name: state.name,
      current_state: state.state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      total_requests: state.total_requests,
      total_failures: state.total_failures,
      total_successes: state.total_successes,
      last_failure_time: state.last_failure_time,
      failure_rate: if(state.total_requests > 0, do: state.total_failures / state.total_requests, else: 0)
    }
    {:reply, {:ok, stats}, state}
  end

  def handle_call({:record_success}, _from, state) do
    new_state = record_success(state)
    {:reply, :ok, new_state}
  end

  def handle_call({:record_failure}, _from, state) do
    new_state = record_failure(state)
    {:reply, :ok, new_state}
  end

  # Private functions

  defp via_tuple(name) do
    {:via, Registry, {RealProductSizeBackend.CircuitBreakerRegistry, name}}
  end

  defp execute_with_fallback(fun, fallback) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, reason} ->
        case fallback do
          nil -> {:error, reason}
          fallback_fun -> execute_fallback(fallback_fun)
        end
    end
  end

  defp execute_fallback(nil), do: {:error, :no_fallback_available}
  defp execute_fallback(fallback_fun) when is_function(fallback_fun), do: fallback_fun.()
  defp execute_fallback(fallback_value), do: {:ok, fallback_value}

  defp attempt_recovery(service_name, fun, fallback) do
    case fun.() do
      {:ok, result} ->
        record_success_to_server(service_name)
        {:ok, result}

      {:error, _reason} ->
        record_failure_to_server(service_name)
        execute_fallback(fallback)
    end
  end

  # Private functions

  defp record_success_to_server(service_name) do
    GenServer.call(via_tuple(service_name), {:record_success})
  end

  defp record_failure_to_server(service_name) do
    GenServer.call(via_tuple(service_name), {:record_failure})
  end

  defp record_success(state) do
    new_state = %{state |
      success_count: state.success_count + 1,
      total_successes: state.total_successes + 1,
      total_requests: state.total_requests + 1
    }

    # Check if we should close the circuit
    if new_state.state == :half_open and new_state.success_count >= new_state.config.success_threshold do
      Logger.info("Circuit breaker closing for #{state.name} after #{new_state.success_count} successes")
      %{new_state | state: :closed, failure_count: 0, success_count: 0}
    else
      new_state
    end
  end

  defp record_failure(state) do
    new_state = %{state |
      failure_count: state.failure_count + 1,
      total_failures: state.total_failures + 1,
      total_requests: state.total_requests + 1,
      last_failure_time: DateTime.utc_now()
    }

    # Check if we should open the circuit
    if new_state.failure_count >= new_state.config.failure_threshold do
      Logger.warning("Circuit breaker opening for #{state.name} after #{new_state.failure_count} failures")
      %{new_state | state: :open, failure_count: 0, success_count: 0}
    else
      new_state
    end
  end

  @doc """
  Test function for development.
  """
  def test_circuit_breaker do
    # Start a test circuit breaker
    {:ok, _pid} = start_link({:test_service, %{failure_threshold: 3, timeout: 30_000}})

    # Test successful calls
    success_fun = fn -> {:ok, "success"} end
    failure_fun = fn -> {:error, "failure"} end
    fallback_fun = fn -> {:ok, "fallback"} end

    # Test normal operation
    case call_with_circuit_breaker(:test_service, success_fun) do
      {:ok, "success"} -> Logger.info("Success test passed")
      other -> Logger.error("Success test failed: #{inspect(other)}")
    end

    # Test failure handling
    case call_with_circuit_breaker(:test_service, failure_fun, fallback_fun) do
      {:ok, "fallback"} -> Logger.info("Fallback test passed")
      other -> Logger.error("Fallback test failed: #{inspect(other)}")
    end

    # Test circuit breaker stats
    case get_circuit_stats(:test_service) do
      {:ok, stats} -> Logger.info("Circuit breaker stats: #{inspect(stats)}")
      other -> Logger.error("Stats test failed: #{inspect(other)}")
    end

    :ok
  end
end
