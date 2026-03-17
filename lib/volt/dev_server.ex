defmodule Volt.DevServer do
  @moduledoc """
  Plug that serves compiled frontend assets in development.

  Intercepts requests under the configured path prefix, compiles
  source files on demand, caches by mtime, and serves with
  correct MIME types and sourcemaps.

  ## Options

    * `:root` — source directory (required, e.g. `"assets/src"`)
    * `:prefix` — URL prefix to intercept (default: `"/assets"`)
    * `:target` — JS downlevel target (e.g. `"es2020"`)
    * `:import_source` — JSX import source (e.g. `"vue"`)
    * `:vapor` — use Vue Vapor mode (default: `false`)

  ## Example

      plug Volt.DevServer,
        root: "assets/src",
        prefix: "/assets",
        target: "es2020"
  """

  @behaviour Plug

  @compilable_exts ~w(.vue .ts .tsx .js .jsx .mts .mjs .css .json)

  @impl true
  def init(opts) do
    root = Keyword.fetch!(opts, :root) |> Path.expand()
    prefix = Keyword.get(opts, :prefix, "/assets")

    %{
      root: root,
      prefix: prefix,
      target: Keyword.get(opts, :target, ""),
      import_source: Keyword.get(opts, :import_source, ""),
      vapor: Keyword.get(opts, :vapor, false),
      plugins: Keyword.get(opts, :plugins, []),
      aliases: Keyword.get(opts, :aliases, %{})
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

  def call(%Plug.Conn{request_path: "/@vendor/" <> specifier_js} = conn, _config) do
    specifier = String.trim_trailing(specifier_js, ".js") |> String.replace("_", "/")

    case Volt.Vendor.read(specifier) do
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
    prefix_len = byte_size(prefix)

    case path do
      <<^prefix::binary-size(prefix_len), "/" <> rest>> -> {:ok, rest}
      ^prefix -> {:ok, ""}
      _ -> :no_match
    end
  end

  defp serve(conn, relative, config) do
    file_path = Path.join(config.root, relative)

    cond do
      compilable?(file_path) and File.regular?(file_path) ->
        serve_compiled(conn, file_path, relative, config)

      Volt.Assets.asset?(file_path) and File.regular?(file_path) ->
        serve_asset(conn, file_path)

      true ->
        conn
    end
  end

  defp compilable?(path), do: Path.extname(path) in @compilable_exts

  defp serve_compiled(conn, file_path, relative, config) do
    Volt.Cache.init()
    mtime = file_mtime(file_path)
    content_type = content_type_for(file_path)

    case Volt.Cache.get(file_path, mtime) do
      %{code: code} = entry ->
        send_compiled(conn, code, entry[:sourcemap], content_type)

      nil ->
        compile_and_serve(conn, file_path, relative, mtime, content_type, config)
    end
  end

  defp compile_and_serve(conn, file_path, _relative, mtime, content_type, config) do
    source = File.read!(file_path)

    pipeline_opts = [
      target: config.target,
      import_source: config.import_source,
      vapor: config.vapor,
      sourcemap: true,
      plugins: config.plugins
    ]

    case Volt.Pipeline.compile(file_path, source, pipeline_opts) do
      {:ok, result} ->
        entry = %{
          code: result.code,
          sourcemap: result.sourcemap,
          css: result.css,
          content_type: content_type
        }

        Volt.Cache.put(file_path, mtime, entry)
        send_compiled(conn, result.code, result.sourcemap, content_type)

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

  defp file_mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> 0
    end
  end

  defp error_overlay(errors) do
    msg =
      errors
      |> List.wrap()
      |> Enum.map_join("\\n", fn
        %{message: m} -> m
        e when is_binary(e) -> e
        e -> inspect(e)
      end)

    """
    console.error("[Volt] Compilation error:\\n#{msg}");
    if (typeof document !== 'undefined') {
      const d = document.createElement('div');
      d.style.cssText = 'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto';
      d.textContent = "[Volt] Compilation error:\\n\\n#{msg}";
      document.body.appendChild(d);
    }
    """
  end
end
