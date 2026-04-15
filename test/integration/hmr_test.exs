defmodule Volt.Integration.TestPlug do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    if String.ends_with?(conn.request_path, ".html") or conn.request_path == "/" do
      file =
        case conn.request_path do
          "/" -> "index.html"
          "/" <> rest -> rest
        end

      path = Path.join(opts[:root], file)

      if File.regular?(path) do
        body = File.read!(path)

        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(200, body)
        |> Plug.Conn.halt()
      else
        Plug.Conn.send_resp(conn, 404, "not found")
      end
    else
      case Volt.DevServer.call(conn, opts[:dev_server]) do
        %{halted: true} = conn -> conn
        conn -> Plug.Conn.send_resp(conn, 404, "not found")
      end
    end
  end
end

defmodule Volt.Integration.HMRTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias PlaywrightEx.{Browser, BrowserContext, Frame}

  @fixture_dir Path.expand("../fixtures/integration_hmr", __DIR__)
  @port 44_831

  setup_all do
    {:ok, _} = PlaywrightEx.Supervisor.start_link(timeout: 10_000)
    {:ok, browser} = PlaywrightEx.launch_browser(:chromium, timeout: 10_000)
    on_exit(fn -> :ok end)
    %{browser: browser}
  end

  setup %{browser: browser} do
    File.rm_rf!(@fixture_dir)
    File.mkdir_p!(@fixture_dir)
    Volt.Cache.clear()
    Volt.DepGraph.clear()

    write_fixture("index.html", """
    <!DOCTYPE html>
    <html>
    <head><title>Volt HMR Test</title></head>
    <body>
      <script type="module" src="/assets/app.ts"></script>
    </body>
    </html>
    """)

    write_fixture("app.ts", """
    const el = document.createElement('div')
    el.id = 'volt-test'
    el.textContent = 'hello from volt'
    document.body.appendChild(el)
    """)

    dev_server_opts = Volt.DevServer.init(root: @fixture_dir, prefix: "/assets")
    plug_opts = %{root: @fixture_dir, dev_server: dev_server_opts}

    {:ok, server} =
      Bandit.start_link(
        plug: {Volt.Integration.TestPlug, plug_opts},
        port: @port,
        ip: :loopback,
        startup_log: false
      )

    {:ok, context} = Browser.new_context(browser.guid, timeout: 5000)
    {:ok, %{main_frame: frame}} = BrowserContext.new_page(context.guid, timeout: 5000)

    on_exit(fn ->
      BrowserContext.close(context.guid, timeout: 5000)
      Process.exit(server, :normal)
      Process.sleep(100)
      File.rm_rf!(@fixture_dir)
    end)

    %{frame: frame, context: context}
  end

  describe "dev server module serving" do
    test "serves compiled TypeScript and executes in browser", %{frame: frame} do
      {:ok, _} = Frame.goto(frame.guid, url: base_url(), timeout: 10_000)

      {:ok, text} =
        Frame.wait_for_function(frame.guid,
          expression: "document.getElementById('volt-test')?.textContent",
          timeout: 5000
        )

      assert text
    end

    test "injects import.meta.hot into served modules", %{frame: frame} do
      write_fixture("hot_check.ts", """
      window.__voltHotAvailable = typeof import.meta.hot?.accept === 'function'
      """)

      write_fixture("hot_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/hot_check.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/hot_page.html"), timeout: 10_000)

      {:ok, result} = eval_poll(frame, "window.__voltHotAvailable")
      assert result == true
    end

    test "rewrites relative imports between modules", %{frame: frame} do
      write_fixture("utils.ts", """
      export const greeting = 'hello from utils'
      """)

      write_fixture("importer.ts", """
      import { greeting } from './utils'
      window.__voltImportResult = greeting
      """)

      write_fixture("import_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/importer.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/import_page.html"), timeout: 10_000)

      {:ok, result} = eval_poll(frame, "window.__voltImportResult")
      assert result == "hello from utils"
    end
  end

  defp eval_poll(frame, expression, attempts \\ 20) do
    {:ok, result} =
      Frame.evaluate(frame.guid,
        expression: expression,
        is_function: false,
        arg: nil,
        timeout: 5000
      )

    if result != nil do
      {:ok, result}
    else
      if attempts > 0 do
        Process.sleep(100)
        eval_poll(frame, expression, attempts - 1)
      else
        {:error, :timeout}
      end
    end
  end

  defp base_url(path \\ "/"), do: "http://localhost:#{@port}#{path}"

  defp write_fixture(name, content) do
    File.write!(Path.join(@fixture_dir, name), content)
  end
end
