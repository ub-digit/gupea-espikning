defmodule Espikning.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EspikningWeb.Telemetry,
      Espikning.Repo,
      {DNSCluster, query: Application.get_env(:espikning, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Espikning.PubSub},
      Espikning.DSpaceAPI.Client,

      # Start a worker by calling: Espikning.Worker.start_link(arg)
      # {Espikning.Worker, arg},
      # Start to serve requests, typically the last entry
      EspikningWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Espikning.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EspikningWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
