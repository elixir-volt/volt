defmodule VanillaExample.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VanillaExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:vanilla_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: VanillaExample.PubSub},
      VanillaExampleWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: VanillaExample.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    VanillaExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
