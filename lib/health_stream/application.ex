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
      {Phoenix.PubSub, name: HealthStream.PubSub}
    ]

    children =
      if Mix.env() == :test do
        children
      else
        children ++
          [
            # Broadway pipeline for processing vital signs
            HealthStream.VitalSignsPipeline,
            # Start the device simulator for generating vital signs
            Supervisor.child_spec(
              {HealthStream.DeviceSimulator,
               patient_id: "P001", device_id: "DEV001", name: :patient_p001},
              id: :patient_p001
            ),
            Supervisor.child_spec(
              {HealthStream.DeviceSimulator,
               patient_id: "P002", device_id: "DEV002", name: :patient_p002},
              id: :patient_p002
            )
          ]
      end ++
        [
          # Start the endpoint when the application starts
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
