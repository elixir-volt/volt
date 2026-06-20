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

  alias Plug.Conn
  alias Volt.URL

  @behaviour Plug

  @impl true
  def init(opts) do
    profile = Keyword.get(opts, :profile)
    build_opts = Keyword.delete(opts, :profile)
    config = Volt.Config.build(profile, build_opts)
    server_config = Volt.Config.server(profile, build_opts)

    root = Keyword.get(opts, :root) || to_string(config.root)
    expanded_root = Path.expand(root)

    node_modules = NPM.Resolution.PackageResolver.find_node_modules(expanded_root)
    plugins = config.plugins

    module_types = config.module_types

    prebundle_vendor(expanded_root, node_modules, plugins, config.resolve_dirs, module_types)

    %Volt.DevServer.Config{
      root: expanded_root,
      public_dir: Volt.PublicDir.resolve(config.public_dir),
      prefix: server_config.prefix,
      target: to_string(config.target),
      import_source: to_string(config.import_source),
      vapor: config.vapor,
      custom_renderer: config.custom_renderer,
      plugins: plugins,
      aliases: config.aliases,
      node_modules: node_modules,
      resolve_dirs: config.resolve_dirs,
      module_types: module_types,
      define:
        Volt.Env.define(mode: "development", root: File.cwd!(), env_prefix: config.env_prefix),
      hmr_timeout: server_config.hmr_timeout
    }
  end

  @impl true
  def call(%Conn{request_path: "/@volt/ws"} = conn, config) do
    conn
    |> WebSockAdapter.upgrade(Volt.HMR.Socket, [], timeout: config.hmr_timeout)
    |> Conn.halt()
  end

  def call(%Conn{request_path: "/@volt/client.js"} = conn, config) do
    heartbeat_interval = max(div(config.hmr_timeout, 2), 1_000)
    client = Volt.JS.Asset.compiled!("dev/hmr-client.ts")
    bootstrap = "globalThis.__VOLT_HEARTBEAT__ = #{heartbeat_interval};\n"

    conn
    |> Conn.put_resp_content_type("application/javascript")
    |> Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> Conn.send_resp(200, bootstrap <> client)
    |> Conn.halt()
  end

  def call(%Conn{method: "POST", request_path: "/@volt/console"} = conn, _config) do
    {:ok, body, conn} = Conn.read_body(conn)
    Volt.Dev.ConsoleForwarder.log(body)

    conn
    |> Conn.send_resp(204, "")
    |> Conn.halt()
  end

  def call(%Conn{request_path: "/@vendor/" <> specifier_js} = conn, config) do
    conn = Conn.fetch_query_params(conn)
    specifier = specifier_js |> String.trim_trailing(".js") |> Volt.JS.Vendor.decode_specifier()

    case serve_vendor(specifier, config, conn.query_params["v"]) do
      {:ok, code} ->
        conn
        |> Conn.put_resp_content_type("application/javascript")
        |> Conn.put_resp_header("cache-control", "max-age=31536000, immutable")
        |> Conn.send_resp(200, code)
        |> Conn.halt()

      {:error, :outdated} ->
        conn
        |> Conn.put_resp_content_type("application/javascript")
        |> Conn.send_resp(504, "// outdated optimized dependency: #{specifier}")
        |> Conn.halt()

      {:error, _} ->
        conn
        |> Conn.send_resp(404, "// vendor module not found: #{specifier}")
        |> Conn.halt()
    end
  end

  def call(%Conn{request_path: request_path} = conn, config) do
    prefix = config.prefix

    case Volt.PublicDir.lookup(config.public_dir, request_path) do
      public_path when is_binary(public_path) ->
        serve_public(conn, public_path)

      nil ->
        case strip_prefix(request_path, prefix) do
          {:ok, relative} ->
            serve(conn, relative, config)

          :no_match ->
            conn
        end
    end
  end

  defp serve_public(conn, path) do
    conn
    |> Conn.put_resp_content_type(Volt.Assets.mime_type(path))
    |> Conn.send_file(200, path)
    |> Conn.halt()
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
    file_path = config.root |> Path.join(relative) |> Path.expand()

    cond do
      not Volt.Path.inside?(file_path, config.root) ->
        conn

      compilable?(file_path, config) and File.regular?(file_path) ->
        serve_compiled(conn, file_path, relative, config)

      Volt.Assets.asset?(file_path) and File.regular?(file_path) ->
        if asset_import_request?(conn) do
          serve_asset_module(conn, file_path, relative, config)
        else
          serve_asset(conn, file_path)
        end

      true ->
        conn
    end
  end

  defp compilable?(path, config),
    do: Path.extname(path) in Volt.JS.Extensions.compilable(config.plugins)

  defp serve_compiled(conn, file_path, relative, config) do
    mtime = Volt.Format.file_mtime(file_path)
    css_import? = css_import_request?(conn, file_path)
    content_type = content_type_for(file_path, css_import?)
    cache_key = cache_key_for(file_path, css_import?)

    case Volt.Cache.get(cache_key, mtime) do
      %{code: code, sourcemap: sourcemap} ->
        send_compiled(conn, code, sourcemap, content_type)

      nil ->
        compile_and_serve(
          conn,
          file_path,
          relative,
          mtime,
          content_type,
          cache_key,
          css_import?,
          config
        )
    end
  end

  defp compile_and_serve(
         conn,
         file_path,
         relative,
         mtime,
         content_type,
         cache_key,
         css_import?,
         config
       ) do
    source = File.read!(file_path)

    pipeline_opts = [
      target: config.target,
      import_source: config.import_source,
      vapor: config.vapor,
      custom_renderer: config.custom_renderer,
      sourcemap: true,
      plugins: config.plugins,
      define: config.define,
      rewrite_import: &rewrite_dev_specifier(&1, file_path, config)
    ]

    case Volt.Pipeline.compile(file_path, source, pipeline_opts) do
      {:ok, result} ->
        Volt.HMR.GlobGraph.update_from_source(file_path, source)
        Volt.HMR.ImportGraph.update_from_compiled(file_path, result.code)

        result = rewrite_dev_css_urls(result, file_path, config)
        mod_url = Volt.URL.join(config.prefix, relative)
        code = code_for_request(result, mod_url, content_type, css_import?)
        graph_url = if css_import?, do: URL.append_query(mod_url, "import"), else: mod_url
        update_module_graph(graph_url, graph_url, file_path, code, source, content_type)

        entry = %Volt.DevServer.CacheEntry{
          code: code,
          sourcemap: result.sourcemap,
          css: result.css,
          hashes: result.hashes,
          content_type: content_type
        }

        Volt.Cache.put(cache_key, mtime, entry)
        send_compiled(conn, code, result.sourcemap, content_type)

      {:error, errors} ->
        conn
        |> Conn.put_resp_content_type("application/javascript")
        |> Conn.send_resp(500, error_overlay(errors))
        |> Conn.halt()
    end
  end

  defp update_module_graph(mod_url, cache_key, file_path, code, source, content_type) do
    imports =
      case OXC.select(code, Path.basename(file_path), :import_specifiers) do
        {:ok, imports} -> Enum.map(imports, &normalize_module_graph_import(&1, mod_url))
        {:error, _} -> []
      end

    Volt.HMR.ModuleGraph.update_module(mod_url, cache_key, file_path, imports,
      type: module_graph_type(content_type),
      self_accepting: Volt.HMR.Boundary.self_accepting?(source)
    )
  end

  defp normalize_module_graph_import("/" <> _ = specifier, _graph_url),
    do: strip_cache_query(specifier)

  defp normalize_module_graph_import("." <> _ = specifier, graph_url) do
    graph_url
    |> Path.dirname()
    |> Path.join(specifier)
    |> Path.expand("/")
    |> strip_cache_query()
  end

  defp normalize_module_graph_import(specifier, _graph_url), do: specifier

  defp strip_cache_query(specifier) do
    uri = URI.parse(specifier)

    query =
      (uri.query || "")
      |> Volt.URL.decode_query()
      |> Map.drop(["t", "v"])
      |> URI.encode_query()

    %{uri | query: if(query == "", do: nil, else: query)}
    |> URI.to_string()
  end

  defp module_graph_type("text/css"), do: :css
  defp module_graph_type(_content_type), do: :js

  defp send_compiled(conn, code, sourcemap, content_type) do
    body =
      if sourcemap do
        encoded = Base.encode64(sourcemap)
        code <> "\n//# sourceMappingURL=data:application/json;base64,#{encoded}\n"
      else
        code
      end

    conn
    |> Conn.put_resp_content_type(content_type)
    |> Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> Conn.send_resp(200, body)
    |> Conn.halt()
  end

  defp serve_asset(conn, file_path) do
    mime = Volt.Assets.mime_type(file_path)

    conn
    |> Conn.put_resp_content_type(mime)
    |> Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> Conn.send_file(200, file_path)
    |> Conn.halt()
  end

  defp serve_asset_module(conn, file_path, relative, config) do
    query = Volt.Assets.Query.decode(conn.query_string)
    url_path = Volt.URL.join(config.prefix, relative)
    prefix = Path.dirname(url_path)

    opts = [
      prefix: prefix,
      url_path: url_path,
      raw: Map.has_key?(query, "raw"),
      url: Map.has_key?(query, "url"),
      inline: Map.has_key?(query, "inline"),
      no_inline: Map.has_key?(query, "no-inline")
    ]

    case Volt.Assets.to_js_module(file_path, opts) do
      {:ok, code} ->
        conn
        |> Conn.put_resp_content_type("application/javascript")
        |> Conn.put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> Conn.send_resp(200, code)
        |> Conn.halt()

      {:error, reason} ->
        conn
        |> Conn.put_resp_content_type("application/javascript")
        |> Conn.send_resp(500, "// asset module error: #{inspect(reason)}")
        |> Conn.halt()
    end
  end

  defp content_type_for(path, css_import?) do
    case {Path.extname(path), css_import?} do
      {".css", false} -> "text/css"
      _ -> "application/javascript"
    end
  end

  defp css_import_request?(conn, file_path) do
    Path.extname(file_path) == ".css" and
      (Volt.CSS.Modules.css_module?(file_path) or import_query?(conn.query_string))
  end

  defp asset_import_request?(conn) do
    Volt.Assets.Query.module_request?(conn.query_string) or
      Enum.member?(Conn.get_req_header(conn, "sec-fetch-dest"), "script")
  end

  defp import_query?(query_string) do
    query_string
    |> URL.decode_query()
    |> Map.has_key?("import")
  end

  defp cache_key_for(file_path, true), do: URL.append_query(file_path, "import")
  defp cache_key_for(file_path, false), do: file_path

  defp rewrite_dev_css_urls(%{type: :css, code: code} = result, file_path, config) do
    case Volt.CSS.AssetURLRewriter.rewrite_dev(code, file_path, config.root, config.prefix) do
      {:ok, code} -> %{result | code: code}
      {:error, _} -> result
    end
  end

  defp rewrite_dev_css_urls(%{css: css} = result, file_path, config) when is_binary(css) do
    case Volt.CSS.AssetURLRewriter.rewrite_dev(css, file_path, config.root, config.prefix) do
      {:ok, css} -> %{result | css: css}
      {:error, _} -> result
    end
  end

  defp rewrite_dev_css_urls(result, _file_path, _config), do: result

  defp code_for_request(result, mod_url, content_type, true) do
    result
    |> css_import_module(mod_url)
    |> maybe_inject_hmr_preamble(URL.append_query(mod_url, "import"), content_type)
    |> maybe_inject_dev_console_forwarder(content_type)
  end

  defp code_for_request(result, mod_url, content_type, false) do
    result.code
    |> maybe_inject_hmr_preamble(mod_url, content_type)
    |> maybe_inject_dev_console_forwarder(content_type)
  end

  defp css_import_module(%{code: code, css: nil}, mod_url) do
    css_update_module(mod_url, code, "")
  end

  defp css_import_module(%{code: code, css: css}, mod_url) do
    css_update_module(mod_url, css, code)
  end

  defp css_update_module(mod_url, css, exports) do
    [
      Volt.JS.Asset.compiled_template!("dev/css-update.ts", id: mod_url, css: css),
      "\n",
      exports
    ]
    |> IO.iodata_to_binary()
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
    case NPM.Resolution.PackageResolver.resolve(specifier, Path.dirname(importer),
           extensions: Volt.JS.Extensions.resolvable(config.plugins),
           conditions: Volt.JS.Resolution.browser_conditions()
         ) do
      {:ok, resolved} -> rewrite_resolved_path(resolved, config)
      _ -> :keep
    end
  end

  defp rewrite_relative(specifier, importer, config) do
    {path_specifier, query} = URL.split_query(specifier)
    resolved = Path.expand(Path.join(Path.dirname(importer), path_specifier))

    rewrite_root_path(resolved, query, config)
  end

  defp rewrite_resolved_path(resolved, config) do
    {resolved, query} = URL.split_query(resolved)
    rewrite_root_path(resolved, query, config)
  end

  defp rewrite_root_path(resolved, query, config) do
    if Volt.Path.inside?(resolved, config.root) do
      resolved = resolve_with_extension(resolved, config.plugins)
      relative = Path.relative_to(resolved, config.root)
      {:rewrite, dev_url_for(config.prefix, relative, resolved, query)}
    else
      :keep
    end
  end

  defp rewrite_bare(specifier, config) do
    specifier = Volt.PluginRunner.prebundle_alias(config.plugins, specifier)

    {:rewrite, Volt.JS.Vendor.vendor_url(specifier, vendor_opts(config))}
  end

  defp dev_url_for(prefix, relative, resolved, query) do
    url = Volt.URL.join(prefix, relative)

    cond do
      query != "" -> URL.append_query(url, query)
      Path.extname(resolved) == ".css" -> URL.append_query(url, "import")
      Volt.Assets.asset?(resolved) -> URL.append_query(url, "import")
      true -> url
    end
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
    Volt.JS.Asset.compiled_template!("dev/hmr-preamble.ts", mod_url: mod_url)
  end

  # ── Vendor pre-bundling ───────────────────────────────────────────

  defp prebundle_vendor(root, node_modules, plugins, resolve_dirs, module_types) do
    case Volt.JS.Vendor.prebundle(
           root: root,
           node_modules: node_modules,
           plugins: plugins,
           resolve_dirs: resolve_dirs,
           module_types: module_types
         ) do
      {:ok, vendor_map} when map_size(vendor_map) > 0 ->
        count = map_size(vendor_map)
        Logger.debug("[Volt] Pre-bundled #{count} vendor package(s)")

      _ ->
        :ok
    end
  end

  defp serve_vendor(specifier, config, browser_hash) do
    vendor_opts = vendor_opts(config)

    if Volt.JS.Vendor.current_browser_hash?(browser_hash, vendor_opts) do
      read_or_bundle_vendor(specifier, config, vendor_opts)
    else
      {:error, :outdated}
    end
  end

  defp read_or_bundle_vendor(specifier, config, vendor_opts) do
    case Volt.JS.Vendor.read(specifier, vendor_opts) do
      {:ok, _} = ok ->
        ok

      {:error, :not_found} ->
        Volt.JS.Vendor.bundle_on_demand(specifier, config.node_modules, vendor_opts)
    end
  end

  defp vendor_opts(config) do
    [
      node_modules: config.node_modules,
      plugins: config.plugins,
      resolve_dirs: config.resolve_dirs,
      module_types: config.module_types
    ]
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

    overlay = Volt.JS.Asset.compiled!("dev/error-overlay.ts")

    invocation =
      Volt.JS.Asset.compiled_template!("dev/error-overlay-invocation.ts", message: msg)

    overlay <> "\n" <> invocation
  end
end
