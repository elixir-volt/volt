defmodule Mix.Tasks.Volt.Priv.Vendor do
  use Mix.Task

  @shortdoc "Vendor npm packages for browser code under priv"

  @moduledoc """
  Vendors the npm packages that `DIR/package.json` lists into `DIR/node_modules`,
  keeping only the files the sources in `DIR` reach. See `Volt.Priv.Vendor`.

      mix volt.priv.vendor priv/ts
      mix volt.priv.vendor priv/ts --update
      mix volt.priv.vendor priv/ts --check

  ## Options

    * `--update` — resolve the versions again instead of using `DIR/npm.lock`
    * `--check` — fail if the vendored files differ from a fresh vendoring
  """

  @impl true
  def run(args) do
    {opts, dirs} = OptionParser.parse!(args, strict: [update: :boolean, check: :boolean])

    if dirs == [], do: Mix.raise("Expected a directory, such as: mix volt.priv.vendor priv/ts")

    Mix.Task.run("app.config")
    Application.ensure_all_started(:req)

    Enum.each(dirs, fn dir ->
      if opts[:check], do: check!(dir), else: vendor!(dir, opts)
    end)
  end

  defp vendor!(dir, opts) do
    files = Volt.Priv.Vendor.run!(dir, update: opts[:update] == true)
    Mix.shell().info("Vendored #{length(files)} files into #{Path.join(dir, "node_modules")}")
  end

  defp check!(dir) do
    case Volt.Priv.Vendor.stale(dir) do
      [] ->
        Mix.shell().info(IO.ANSI.format([:green, "✓ #{dir} vendored packages are current"]))

      stale ->
        Mix.raise("""
        #{dir}/node_modules is out of date. Run `mix volt.priv.vendor #{dir}`. Differing files:

        #{Enum.map(stale, &["  ", &1, "\n"])}
        """)
    end
  end
end
