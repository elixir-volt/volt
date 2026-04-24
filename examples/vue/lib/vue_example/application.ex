defmodule VueExample.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VueExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:vue_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: VueExample.PubSub},
      VueExampleWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: VueExample.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    VueExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
