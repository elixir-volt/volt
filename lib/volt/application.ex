defmodule Volt.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Volt.Cache.create_table()
    Volt.HMR.ImportGraph.create_table()
    Volt.HMR.GlobGraph.create_table()
    Volt.HMR.StyleGraph.create_table()
    Volt.HMR.ModuleGraph.create_table()

    children = [
      {Registry, keys: :duplicate, name: Volt.HMR.Registry},
      {Registry, keys: :unique, name: Volt.Dev.WatcherRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Volt.Dev.WatcherSupervisor},
      {Volt.Tailwind, Volt.Config.tailwind()}
    ]

    opts = [strategy: :one_for_one, name: Volt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
