defmodule ReactExample.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReactExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:react_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ReactExample.PubSub},
      ReactExampleWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ReactExample.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ReactExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
