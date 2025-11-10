defmodule RealProductSizeBackend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize product cache
    RealProductSizeBackend.ProductCache.init_cache()

    # Initialize security validator
    RealProductSizeBackend.SecurityValidator.init()

    children = [
      {Finch, name: :"RealProductSizeBackend.Finch"},
      RealProductSizeBackendWeb.Telemetry,
      RealProductSizeBackend.Repo,
      {DNSCluster,
       query: Application.get_env(:real_product_size_backend, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RealProductSizeBackend.PubSub},
      # Circuit breaker registry
      RealProductSizeBackend.CircuitBreakerRegistry,
      # Circuit breakers for external services
      {RealProductSizeBackend.CircuitBreaker, {:amazon_api, %{failure_threshold: 3, timeout: 300_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:ikea_api, %{failure_threshold: 3, timeout: 300_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:gemini_api, %{failure_threshold: 5, timeout: 180_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:grok_api, %{failure_threshold: 5, timeout: 180_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:openrouter_api, %{failure_threshold: 5, timeout: 180_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:tripo_api, %{failure_threshold: 3, timeout: 300_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:image_download_api, %{failure_threshold: 5, timeout: 180_000}}},
      {RealProductSizeBackend.CircuitBreaker, {:url_resolve_api, %{failure_threshold: 5, timeout: 180_000}}},
      # Start to serve requests, typically the last entry
      RealProductSizeBackendWeb.Endpoint
    ] ++ if(Mix.env() != :test, do: [{Oban, Application.fetch_env!(:real_product_size_backend, Oban)}], else: [])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RealProductSizeBackend.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # Install dev logger AFTER supervisor/Repo starts, but only if module is available
    # if Code.ensure_loaded?(EctoDevLogger) do
    #   EctoDevLogger.install(RealProductSizeBackend.Repo)
    # end

    {:ok, sup}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RealProductSizeBackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
