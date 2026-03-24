defmodule Mix.Tasks.Volt.Npm do
  use Mix.Task

  @shortdoc "Install JS tooling with npm_ex"

  @moduledoc """
  Install the JavaScript tooling used by Volt.

      mix volt.npm
  """

  @impl true
  def run(_args) do
    Mix.Task.run("npm.install")
  end
end
