defmodule HealthStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HealthStreamWeb.Telemetry,
      HealthStream.Repo,
      {DNSCluster, query: Application.get_env(:health_stream, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HealthStream.PubSub},
      # Start a worker by calling: HealthStream.Worker.start_link(arg)
      # {HealthStream.Worker, arg},
      # Start to serve requests, typically the last entry
      HealthStreamWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HealthStream.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HealthStreamWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
