defmodule Volt do
  @moduledoc """
  Elixir-native frontend build tool.

  Provides a dev server with hot module replacement (HMR) and production
  builds for JavaScript, TypeScript, Vue SFCs, and CSS — powered by
  OXC and Vize Rust NIFs. No Node.js required at runtime.

  ## Setup

  Add Volt to your Phoenix endpoint as a Plug:

      plug Volt.DevServer,
        root: "assets/src",
        target: :es2020

  Or use the Mix tasks:

      mix volt.build       # Production build
  """

  @doc """
  Returns the browser path for the configured Volt entry.

  In development this points at the source module served by `Volt.DevServer`.
  In production it reads `manifest.json` and returns the built asset path.
  """
  def entry_path(endpoint, overrides \\ []) do
    build = Volt.Config.build(overrides)
    server = Volt.Config.server(overrides)
    entry = build.entry |> List.wrap() |> hd()

    if code_reloader?(endpoint) do
      server.prefix
      |> Path.join(Path.relative_to(entry, build.root))
      |> ensure_leading_slash()
    else
      built_entry_path(build, server.prefix, overrides)
    end
  end

  defp built_entry_path(build, prefix, overrides) do
    name = Keyword.get(overrides, :name) || entry_name(build.entry)
    manifest_path = Path.join(build.outdir, "manifest.json")
    manifest_key = "#{name}.js"

    file =
      with {:ok, json} <- File.read(manifest_path),
           manifest when is_map(manifest) <- :json.decode(json),
           %{"file" => file} <- Map.get(manifest, manifest_key) do
        file
      else
        _ -> manifest_key
      end

    prefix
    |> Path.join(file)
    |> ensure_leading_slash()
  end

  defp entry_name(entry) do
    entry
    |> List.wrap()
    |> hd()
    |> Path.basename()
    |> Path.rootname()
  end

  defp code_reloader?(endpoint) do
    endpoint.config(:code_reloader)
  rescue
    _ -> false
  end

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
