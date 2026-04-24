defmodule SvelteExample.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SvelteExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:svelte_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SvelteExample.PubSub},
      SvelteExampleWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SvelteExample.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SvelteExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
