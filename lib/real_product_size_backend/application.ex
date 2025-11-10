defmodule RealProductSizeBackend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Ecto.DevLogger.install(RealProductSizeBackend.Repo)
    children = [
      {Finch, name: :"RealProductSizeBackend.Finch"},
      RealProductSizeBackendWeb.Telemetry,
      RealProductSizeBackend.Repo,
      {DNSCluster, query: Application.get_env(:real_product_size_backend, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RealProductSizeBackend.PubSub},
      # Start a worker by calling: RealProductSizeBackend.Worker.start_link(arg)
      # {RealProductSizeBackend.Worker, arg},
      # Start to serve requests, typically the last entry
      RealProductSizeBackendWeb.Endpoint,
      {Oban, Application.fetch_env!(:RealProductSizeBackend, Oban)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RealProductSizeBackend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RealProductSizeBackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
