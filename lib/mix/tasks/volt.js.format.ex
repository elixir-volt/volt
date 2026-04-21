defmodule Mix.Tasks.Volt.Js.Format do
  use Mix.Task

  @shortdoc "Format Volt TypeScript assets"

  @moduledoc """
  Format Volt's JavaScript and TypeScript assets with oxfmt via NIF.

      mix volt.js.format

  Reads options from `config :volt, :format`. Falls back to `.oxfmtrc.json`.
  No Node.js required.
  """

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")

    opts = Volt.JS.Format.load_config()
    dir = Volt.JS.Helpers.assets_dir()
    files = Volt.JS.Helpers.discover_files(dir)

    if files == [] do
      Mix.shell().info("No formattable files found in #{dir}/")
    else
      {changed, total} = format_files(files, opts)

      if changed == 0 do
        Mix.shell().info("All #{total} files already formatted")
      else
        Mix.shell().info("Formatted #{changed}/#{total} files")
      end
    end
  end

  defp format_files(files, opts) do
    changed =
      Enum.count(files, fn file ->
        source = File.read!(file)
        formatted = OXC.Format.run!(source, file, opts)

        if formatted != source do
          File.write!(file, formatted)
          true
        else
          false
        end
      end)

    {changed, length(files)}
  end
end
