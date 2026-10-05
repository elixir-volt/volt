defmodule Volt.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Volt.Paths.capture_root()
    Volt.Cache.create_table()
    Volt.Dev.Assets.create_table()
    Volt.HMR.ImportGraph.create_table()
    Volt.HMR.GlobGraph.create_table()
    Volt.HMR.StyleGraph.create_table()
    Volt.HMR.ModuleGraph.create_table()
    Volt.HMR.Errors.create_table()

    # Watchers release their Tailwind contexts when they terminate, so the
    # Tailwind processes start before them and stop after them.
    children = [
      {Registry, keys: :duplicate, name: Volt.HMR.Registry},
      {Registry, keys: :unique, name: Volt.Tailwind.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Volt.Tailwind.WorkerSupervisor},
      Volt.Tailwind.Runtime,
      {Registry, keys: :unique, name: Volt.Dev.WatcherRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Volt.Dev.WatcherSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Volt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
