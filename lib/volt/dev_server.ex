defmodule Volt.DevServer do
  @moduledoc """
  Plug that serves compiled frontend assets in development.

  Serves individual ESM modules — each `.ts`, `.vue`, `.jsx` file gets
  its own URL under the configured prefix. Import specifiers are rewritten
  so the browser can resolve the full module graph:

    * Relative imports (`./utils`) → `/assets/utils.ts`
    * Bare imports (`vue`) → `/@vendor/vue.js` (pre-bundled)
    * Alias imports (`@/utils`) → `/assets/utils.ts`

  Each module includes an `import.meta.hot` runtime for HMR support.

  ## Options

    * `:root` — source directory (required, e.g. `"assets/src"`)
    * `:prefix` — URL prefix to intercept (default: `"/assets"`)
    * `:target` — JS downlevel target (e.g. `:es2020`)
    * `:import_source` — JSX import source (e.g. `"vue"`)
    * `:vapor` — use Vue Vapor mode (default: `false`)

  ## Example

      plug Volt.DevServer,
        root: "assets/src",
        prefix: "/assets",
        target: :es2020
  """

  require Logger

  @behaviour Plug

  @impl true
  def init(opts) do
    config = Volt.Config.build(opts)
    server_config = Volt.Config.server(opts)

    root = Keyword.get(opts, :root) || to_string(config.root)
    expanded_root = Path.expand(root)

    node_modules = NPM.Resolution.PackageResolver.find_node_modules(expanded_root)
    plugins = config.plugins

    prebundle_vendor(expanded_root, node_modules, plugins)

    %{
      root: expanded_root,
      prefix: server_config.prefix,
      target: to_string(config.target),
      import_source: to_string(config.import_source),
      vapor: config.vapor,
      custom_renderer: config.custom_renderer,
      plugins: plugins,
      aliases: config.aliases,
      node_modules: node_modules
    }
  end

  @impl true
  def call(%Plug.Conn{request_path: "/@volt/ws"} = conn, _config) do
    conn
    |> WebSockAdapter.upgrade(Volt.HMR.Socket, [], timeout: 60_000)
    |> Plug.Conn.halt()
  end

  def call(%Plug.Conn{request_path: "/@volt/client.js"} = conn, _config) do
    conn
    |> Plug.Conn.put_resp_content_type("application/javascript")
    |> Plug.Conn.send_resp(200, Volt.HMR.Client.js())
    |> Plug.Conn.halt()
  end

  def call(%Plug.Conn{method: "POST", request_path: "/@volt/console"} = conn, _config) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Volt.Dev.ConsoleForwarder.log(body)

    conn
    |> Plug.Conn.send_resp(204, "")
    |> Plug.Conn.halt()
  end

  def call(%Plug.Conn{request_path: "/@vendor/" <> specifier_js} = conn, config) do
    specifier = specifier_js |> String.trim_trailing(".js") |> Volt.JS.Vendor.decode_specifier()

    case serve_vendor(specifier, config) do
      {:ok, code} ->
        conn
        |> Plug.Conn.put_resp_content_type("application/javascript")
        |> Plug.Conn.put_resp_header("cache-control", "max-age=31536000, immutable")
        |> Plug.Conn.send_resp(200, code)
        |> Plug.Conn.halt()

      {:error, _} ->
        conn
        |> Plug.Conn.send_resp(404, "// vendor module not found: #{specifier}")
        |> Plug.Conn.halt()
    end
  end

  def call(%Plug.Conn{request_path: request_path} = conn, config) do
    prefix = config.prefix

    case strip_prefix(request_path, prefix) do
      {:ok, relative} ->
        serve(conn, relative, config)

      :no_match ->
        conn
    end
  end

  defp strip_prefix(path, prefix) do
    case String.replace_prefix(path, prefix <> "/", "") do
      ^path ->
        if path == prefix, do: {:ok, ""}, else: :no_match

      rest ->
        {:ok, rest}
    end
  end

  defp serve(conn, relative, config) do
    file_path = Path.join(config.root, relative)

    cond do
      compilable?(file_path, config) and File.regular?(file_path) ->
        serve_compiled(conn, file_path, relative, config)

      Volt.Assets.asset?(file_path) and File.regular?(file_path) ->
        serve_asset(conn, file_path)

      true ->
        conn
    end
  end

  defp compilable?(path, config),
    do: Path.extname(path) in Volt.JS.Extensions.compilable(config.plugins)

  defp serve_compiled(conn, file_path, relative, config) do
    mtime = Volt.Format.file_mtime(file_path)
    content_type = content_type_for(file_path)

    case Volt.Cache.get(file_path, mtime) do
      %{code: code} = entry ->
        send_compiled(conn, code, entry[:sourcemap], content_type)

      nil ->
        compile_and_serve(conn, file_path, relative, mtime, content_type, config)
    end
  end

  defp compile_and_serve(conn, file_path, relative, mtime, content_type, config) do
    source = File.read!(file_path)

    pipeline_opts = [
      target: config.target,
      import_source: config.import_source,
      vapor: config.vapor,
      custom_renderer: config.custom_renderer,
      sourcemap: true,
      plugins: config.plugins,
      rewrite_import: &rewrite_dev_specifier(&1, file_path, config)
    ]

    case Volt.Pipeline.compile(file_path, source, pipeline_opts) do
      {:ok, result} ->
        mod_url = Path.join(config.prefix, relative)
        code = maybe_inject_hmr_preamble(result.code, mod_url, content_type)
        code = maybe_inject_dev_console_forwarder(code, content_type)

        entry = %{
          code: code,
          sourcemap: result.sourcemap,
          css: result.css,
          hashes: result.hashes,
          content_type: content_type
        }

        Volt.Cache.put(file_path, mtime, entry)
        send_compiled(conn, code, result.sourcemap, content_type)

      {:error, errors} ->
        conn
        |> Plug.Conn.put_resp_content_type("application/javascript")
        |> Plug.Conn.send_resp(500, error_overlay(errors))
        |> Plug.Conn.halt()
    end
  end

  defp send_compiled(conn, code, sourcemap, content_type) do
    body =
      if sourcemap do
        encoded = Base.encode64(sourcemap)
        code <> "\n//# sourceMappingURL=data:application/json;base64,#{encoded}\n"
      else
        code
      end

    conn
    |> Plug.Conn.put_resp_content_type(content_type)
    |> Plug.Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> Plug.Conn.send_resp(200, body)
    |> Plug.Conn.halt()
  end

  defp serve_asset(conn, file_path) do
    mime = Volt.Assets.mime_type(file_path)

    conn
    |> Plug.Conn.put_resp_content_type(mime)
    |> Plug.Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> Plug.Conn.send_file(200, file_path)
    |> Plug.Conn.halt()
  end

  defp content_type_for(path) do
    case Path.extname(path) do
      ".css" -> "text/css"
      ".json" -> "application/javascript"
      _ -> "application/javascript"
    end
  end

  # ── Import rewriting ──────────────────────────────────────────────

  defp rewrite_dev_specifier(specifier, importer, config) do
    cond do
      NPM.Resolution.PackageResolver.node_builtin?(specifier) ->
        :keep

      String.starts_with?(specifier, "#") ->
        rewrite_package_import(specifier, importer, config)

      NPM.Resolution.PackageResolver.relative?(specifier) ->
        rewrite_relative(specifier, importer, config)

      true ->
        case Volt.JS.Resolver.resolve(specifier, config.aliases) do
          {:ok, resolved} -> rewrite_resolved_path(resolved, config)
          :pass -> rewrite_bare(specifier, config)
        end
    end
  end

  defp rewrite_package_import(specifier, importer, config) do
    case Volt.JS.PackageResolver.resolve(specifier, Path.dirname(importer),
           extensions: Volt.JS.Extensions.resolvable(config.plugins)
         ) do
      {:ok, resolved} -> rewrite_resolved_path(resolved, config)
      _ -> :keep
    end
  end

  defp rewrite_relative(specifier, importer, config) do
    resolved = Path.expand(Path.join(Path.dirname(importer), specifier))

    if String.starts_with?(resolved, config.root) do
      resolved = resolve_with_extension(resolved, config.plugins)
      relative = Path.relative_to(resolved, config.root)
      {:rewrite, Path.join(config.prefix, relative)}
    else
      :keep
    end
  end

  defp rewrite_resolved_path(resolved, config) do
    if String.starts_with?(resolved, config.root) do
      resolved = resolve_with_extension(resolved, config.plugins)
      relative = Path.relative_to(resolved, config.root)
      {:rewrite, Path.join(config.prefix, relative)}
    else
      :keep
    end
  end

  defp rewrite_bare(specifier, config) do
    specifier = Volt.PluginRunner.prebundle_alias(config.plugins, specifier)
    {:rewrite, Volt.JS.Vendor.vendor_url(specifier)}
  end

  defp resolve_with_extension(path, plugins) do
    if Path.extname(path) != "" and File.regular?(path) do
      path
    else
      case NPM.Resolution.PackageResolver.try_resolve(path,
             extensions: Volt.JS.Extensions.resolvable(plugins)
           ) do
        {:ok, resolved} -> resolved
        :error -> path
      end
    end
  end

  # ── HMR preamble ──────────────────────────────────────────────────

  defp maybe_inject_hmr_preamble(code, mod_url, "application/javascript") do
    hmr_preamble(mod_url) <> code
  end

  defp maybe_inject_hmr_preamble(code, _relative, _content_type), do: code

  defp hmr_preamble(mod_url) do
    """
    import { createHotContext as __volt_createHotContext } from "/@volt/client.js";
    import.meta.hot = __volt_createHotContext(#{inspect(mod_url)});
    """
  end

  # ── Vendor pre-bundling ───────────────────────────────────────────

  defp prebundle_vendor(root, node_modules, plugins) do
    case Volt.JS.Vendor.prebundle(root: root, node_modules: node_modules, plugins: plugins) do
      {:ok, vendor_map} when map_size(vendor_map) > 0 ->
        count = map_size(vendor_map)
        Logger.debug("[Volt] Pre-bundled #{count} vendor package(s)")

      _ ->
        :ok
    end
  end

  defp serve_vendor(specifier, config) do
    case Volt.JS.Vendor.read(specifier) do
      {:ok, _} = ok ->
        ok

      {:error, :not_found} ->
        Volt.JS.Vendor.bundle_on_demand(specifier, config.node_modules, config.plugins)
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp maybe_inject_dev_console_forwarder(code, "application/javascript") do
    Volt.Dev.ConsoleForwarder.inject(code)
  end

  defp maybe_inject_dev_console_forwarder(code, _content_type), do: code

  defp error_overlay(errors) do
    msg =
      errors
      |> List.wrap()
      |> Enum.map_join("\n", fn
        %{message: m} -> m
        e when is_binary(e) -> e
        e -> inspect(e)
      end)

    overlay = Volt.JS.Asset.compiled!("error-overlay.ts")
    overlay <> "\nrenderErrorOverlay(#{inspect(msg)})\n"
  end
end
