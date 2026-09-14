defmodule Volt.Dev.Cleanup do
  @moduledoc "Cleanup of session-scoped compilation and dependency state."

  def run(session) do
    Volt.Dev.Assets.clear_session(session)
    Volt.Tailwind.Supervisor.release_runtime(session)
    Volt.Cache.clear_session(session)
    Volt.HMR.ImportGraph.clear_session(session)
    Volt.HMR.GlobGraph.clear_session(session)
    Volt.HMR.StyleGraph.clear_session(session)
    Volt.HMR.ModuleGraph.clear_session(session)
    :ok
  end
end
