defmodule Mix.Tasks.Volt.Priv.Vendor do
  use Mix.Task

  @shortdoc "Vendor npm packages for browser code under priv"

  @moduledoc """
  Vendors the npm packages that `DIR/package.json` lists into `DIR/node_modules`,
  keeping only the files the sources in `DIR` reach. See `Volt.Priv.Vendor`.

      mix volt.priv.vendor priv/ts
      mix volt.priv.vendor priv/ts --update

  Run it before `mix hex.publish`, so the package ships the vendored files.

  ## Options

    * `--update` — resolve the versions again instead of using `DIR/npm.lock`
  """

  @impl true
  def run(args) do
    {opts, dirs} = OptionParser.parse!(args, strict: [update: :boolean])

    if dirs == [], do: Mix.raise("Expected a directory, such as: mix volt.priv.vendor priv/ts")

    Mix.Task.run("app.config")
    Application.ensure_all_started(:req)

    for dir <- dirs do
      files = Volt.Priv.Vendor.run!(dir, update: opts[:update] == true)
      Mix.shell().info("Vendored #{length(files)} files into #{Path.join(dir, "node_modules")}")
    end
  end
end
