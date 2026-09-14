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

  alias Volt.URL

  @doc "Build the complete configured frontend output."
  @spec build(keyword()) :: {:ok, Volt.Build.Result.t()} | {:error, term()}
  def build(opts \\ []), do: Volt.Build.run(opts)

  @doc """
  Returns the browser path for a Volt-managed static asset.

  In development, JavaScript entry paths point at the source module served by
  `Volt.DevServer`. In production, Volt reads `manifest.json` and returns the
  built asset path, passing the result through Phoenix `static_path/1` when an
  endpoint is available.
  """
  def static_path(conn_or_socket_or_endpoint_or_uri, path, overrides \\ []) do
    profile = Keyword.get(overrides, :profile)
    build_overrides = Keyword.delete(overrides, :profile)
    build = Volt.Config.build(profile, build_overrides)
    server = Volt.Config.server(profile, build_overrides)
    endpoint = endpoint_from(conn_or_socket_or_endpoint_or_uri)

    resolved_path =
      if code_reloader?(endpoint) do
        dev_static_path(path, build, server)
      else
        built_static_path(endpoint, path, build, server.prefix)
      end

    phoenix_static_path(conn_or_socket_or_endpoint_or_uri, resolved_path)
    |> ensure_leading_slash()
  end

  @doc """
  Returns the browser URL for a Volt-managed static asset.
  """
  def static_url(conn_or_socket_or_endpoint, path, overrides \\ []) do
    resolved_path = static_path(conn_or_socket_or_endpoint, path, overrides)

    case conn_or_socket_or_endpoint do
      %Plug.Conn{private: %{phoenix_static_url: static_url}} ->
        static_url <> resolved_path

      %Plug.Conn{private: %{phoenix_endpoint: endpoint}} ->
        endpoint.static_url() <> resolved_path

      %{endpoint: endpoint} ->
        endpoint.static_url() <> resolved_path

      endpoint when is_atom(endpoint) ->
        endpoint.static_url() <> resolved_path

      other ->
        raise ArgumentError,
              "expected a %Plug.Conn{}, a %Phoenix.Socket{}, a struct with an :endpoint key, " <>
                "or a Phoenix.Endpoint when building static url for #{path}, got: #{inspect(other)}"
    end
  end

  @doc """
  Returns the browser path for the configured Volt entry.

  In development this points at the source module served by `Volt.DevServer`.
  In production it reads `manifest.json` and returns the built asset path.
  """
  @deprecated "use Volt.static_path/2 with the compiled asset path instead"
  def entry_path(endpoint, overrides \\ []) do
    profile = Keyword.get(overrides, :profile)
    build_overrides = Keyword.delete(overrides, :profile)
    build = Volt.Config.build(profile, build_overrides)
    server = Volt.Config.server(profile, build_overrides)
    name = Keyword.get(build_overrides, :name) || entry_name(build.entry)

    static_path(endpoint, URL.join(URL.join(server.prefix, "js"), "#{name}.js"), overrides)
  end

  defp dev_static_path(path, build, server) do
    name = entry_name(build.entry)
    js_path = URL.join(URL.join(server.prefix, "js"), "#{name}.js")

    if normalize_path(path) == normalize_path(js_path) do
      server.prefix
      |> Path.join(Path.relative_to(build.entry |> List.wrap() |> hd(), build.root))
      |> ensure_leading_slash()
    else
      ensure_leading_slash(path)
    end
  end

  defp built_static_path(endpoint, path, build, prefix) do
    case find_manifest_entry(endpoint, build.outdir, prefix, path) do
      {:ok, file, manifest_prefix} -> URL.join(manifest_prefix, file)
      :error -> ensure_leading_slash(path)
    end
  end

  defp find_manifest_entry(endpoint, outdir, prefix, path) do
    root_outdir = resolve_outdir(endpoint, outdir)

    manifest_keys(path, prefix)
    |> Enum.find_value(:error, fn manifest_key ->
      manifest_locations(root_outdir, prefix)
      |> Enum.find_value(fn {manifest_dir, manifest_prefix} ->
        manifest_path = Path.join(manifest_dir, "manifest.json")

        with {:ok, json} <- File.read(manifest_path),
             {:ok, manifest} when is_map(manifest) <- Jason.decode(json),
             %{"file" => file} <- Map.get(manifest, manifest_key) do
          {:ok, file, manifest_prefix}
        else
          _ -> nil
        end
      end)
    end)
  end

  defp manifest_locations(root_outdir, prefix) do
    [
      {root_outdir, prefix},
      {Path.join(root_outdir, "js"), URL.join(prefix, "js")},
      {Path.join(root_outdir, "css"), URL.join(prefix, "css")}
    ]
  end

  defp manifest_keys(path, prefix) do
    normalized_path = normalize_path(path)
    normalized_prefix = normalize_path(prefix)

    relative =
      if String.starts_with?(normalized_path, normalized_prefix <> "/") do
        String.replace_prefix(normalized_path, normalized_prefix <> "/", "")
      else
        String.trim_leading(normalized_path, "/")
      end

    [relative, Path.basename(relative)]
    |> Enum.uniq()
  end

  defp resolve_outdir(endpoint, outdir) do
    outdir = to_string(outdir)

    cond do
      Path.type(outdir) == :absolute ->
        outdir

      endpoint && otp_app(endpoint) ->
        resolve_app_path(otp_app(endpoint), outdir)

      true ->
        Path.expand(outdir)
    end
  end

  defp resolve_app_path(otp_app, "priv/" <> _ = outdir) do
    Application.app_dir(otp_app, outdir)
  rescue
    _ -> Path.expand(outdir)
  end

  defp resolve_app_path(_otp_app, outdir), do: Path.expand(outdir)

  defp phoenix_static_path(%Plug.Conn{private: private}, path) do
    case private do
      %{phoenix_static_url: _} -> path
      %{phoenix_endpoint: endpoint} -> safe_endpoint_static_path(endpoint, path)
      _ -> path
    end
  end

  defp phoenix_static_path(%URI{} = uri, path), do: (uri.path || "") <> path

  defp phoenix_static_path(%{endpoint: endpoint}, path),
    do: safe_endpoint_static_path(endpoint, path)

  defp phoenix_static_path(endpoint, path) when is_atom(endpoint),
    do: safe_endpoint_static_path(endpoint, path)

  defp phoenix_static_path(_other, path), do: path

  defp safe_endpoint_static_path(endpoint, path) do
    endpoint.static_path(path)
  rescue
    UndefinedFunctionError -> path
  end

  defp endpoint_from(%Plug.Conn{private: %{phoenix_endpoint: endpoint}}), do: endpoint
  defp endpoint_from(%{endpoint: endpoint}), do: endpoint
  defp endpoint_from(endpoint) when is_atom(endpoint), do: endpoint
  defp endpoint_from(_other), do: nil

  defp otp_app(endpoint) do
    endpoint.config(:otp_app)
  rescue
    _ -> nil
  end

  defp entry_name(entry) do
    entry
    |> List.wrap()
    |> hd()
    |> Path.basename()
    |> Path.rootname()
  end

  defp code_reloader?(nil), do: false

  defp code_reloader?(endpoint) do
    endpoint.config(:code_reloader)
  rescue
    _ -> false
  end

  defp normalize_path(path), do: "/" <> (path |> to_string() |> String.trim_leading("/"))

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
