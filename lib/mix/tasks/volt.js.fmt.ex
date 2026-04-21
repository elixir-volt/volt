defmodule Mix.Tasks.Volt.Js.Fmt do
  use Mix.Task

  @shortdoc "Format Volt TypeScript assets"

  @moduledoc """
  Format Volt's TypeScript assets with oxfmt via NIF.

      mix volt.js.fmt

  Reads formatting options from `.oxfmtrc.json` if present.
  No Node.js required.
  """

  @extensions ~w(.js .ts .jsx .tsx)

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    opts = Volt.JS.Format.load_config()
    dir = Volt.JS.Helpers.ts_dir()
    files = discover_files(dir)

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

  defp discover_files(dir) do
    Path.wildcard("#{dir}/**/*")
    |> Enum.filter(&(Path.extname(&1) in @extensions))
    |> Enum.sort()
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
