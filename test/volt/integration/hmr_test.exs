defmodule Volt.Integration.TestPlug do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn

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
        |> Conn.put_resp_content_type("text/html")
        |> Conn.send_resp(200, body)
        |> Conn.halt()
      else
        Conn.send_resp(conn, 404, "not found")
      end
    else
      case Volt.DevServer.call(conn, opts[:dev_server]) do
        %{halted: true} = conn -> conn
        conn -> Conn.send_resp(conn, 404, "not found")
      end
    end
  end
end

defmodule Volt.Integration.HMRTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias PlaywrightEx.{Browser, BrowserContext, Frame}

  @fixture_dir Path.join(System.tmp_dir!(), "volt-integration-hmr-test")
  @port 44_831

  setup_all do
    ensure_playwright_started!()
    {:ok, browser} = launch_browser!()
    on_exit(fn -> :ok end)
    %{browser: browser}
  end

  defp ensure_playwright_started! do
    case PlaywrightEx.Supervisor.start_link(timeout: 10_000, executable: playwright_executable()) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp launch_browser! do
    case PlaywrightEx.launch_browser(:chromium, timeout: 10_000) do
      {:ok, browser} ->
        {:ok, browser}

      {:error, _reason} ->
        restart_playwright!()
        PlaywrightEx.launch_browser(:chromium, timeout: 10_000)
    end
  catch
    :exit, _reason ->
      restart_playwright!()
      PlaywrightEx.launch_browser(:chromium, timeout: 10_000)
  end

  defp restart_playwright! do
    case Process.whereis(PlaywrightEx.Supervisor) do
      nil -> :ok
      pid -> Process.exit(pid, :kill)
    end

    Process.sleep(100)
    ensure_playwright_started!()
  end

  defp playwright_executable do
    local = Path.expand("node_modules/playwright/cli.js")
    if File.exists?(local), do: local, else: "playwright"
  end

  setup %{browser: browser} do
    File.rm_rf!(@fixture_dir)
    File.mkdir_p!(@fixture_dir)
    Volt.Cache.clear()
    Volt.HMR.GlobGraph.clear()
    Volt.HMR.ImportGraph.clear()
    Volt.HMR.ModuleGraph.clear()

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

    on_exit(fn -> Process.exit(server, :normal) end)

    {:ok, context} = Browser.new_context(browser.guid, timeout: 5000)
    {:ok, %{main_frame: frame}} = BrowserContext.new_page(context.guid, timeout: 5000)

    on_exit(fn ->
      BrowserContext.close(context.guid, timeout: 5000)
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

    test "imports CSS from JavaScript and injects a style tag", %{frame: frame} do
      write_fixture("imported.css", """
      .volt-css-import-target { color: rgb(10, 20, 30); }
      """)

      write_fixture("css_importer.ts", """
      import './imported.css'

      const el = document.createElement('div')
      el.className = 'volt-css-import-target'
      el.textContent = 'styled'
      document.body.appendChild(el)
      window.__voltCssImportLoaded = true
      """)

      write_fixture("css_import_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/css_importer.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/css_import_page.html"), timeout: 10_000)

      {:ok, loaded} = eval_poll(frame, "window.__voltCssImportLoaded")
      assert loaded == true

      {:ok, style_count} =
        eval_poll(
          frame,
          "document.querySelectorAll('style[data-volt-id=\"/assets/imported.css\"]').length"
        )

      assert style_count == 1

      {:ok, color} =
        eval_poll(
          frame,
          "getComputedStyle(document.querySelector('.volt-css-import-target')).color"
        )

      assert color == "rgb(10, 20, 30)"
    end

    test "self-accepting modules update without reloading and preserve hot data", %{frame: frame} do
      write_fixture("self_accept.ts", """
      const store = (window.__voltSelfAccept ??= { events: [] })
      export const value = 'one'
      store.value = value
      store.previous = import.meta.hot?.data?.previous ?? 'none'

      let el = document.getElementById('self-accept')
      if (!el) {
        el = document.createElement('div')
        el.id = 'self-accept'
        document.body.appendChild(el)
      }
      el.textContent = `${value}:${store.previous}`

      import.meta.hot?.accept((mod) => {
        store.events.push(`accept:${mod.value}`)
      })

      import.meta.hot?.dispose((data) => {
        data.previous = value
        store.events.push(`dispose:${value}`)
      })
      """)

      write_fixture("self_accept_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/self_accept.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/self_accept_page.html"), timeout: 10_000)
      {:ok, initial} = eval_poll(frame, "document.getElementById('self-accept')?.textContent")
      assert initial == "one:none"

      {:ok, watcher} = start_watcher()

      update_fixture("self_accept.ts", &String.replace(&1, "'one'", "'two'"))

      assert {:ok, "two:one"} =
               eval_until(frame, "document.getElementById('self-accept')?.textContent", "two:one")

      assert {:ok, true} =
               eval_until(
                 frame,
                 "window.__voltSelfAccept.events.includes('dispose:one') && window.__voltSelfAccept.events.includes('accept:two')",
                 true
               )

      GenServer.stop(watcher)
    end

    test "parent modules accept dependency updates without reloading", %{frame: frame} do
      write_fixture("accepted_dep.ts", """
      export const value = 'child-one'
      """)

      write_fixture("accept_parent.ts", """
      import { value } from './accepted_dep'

      const store = (window.__voltAcceptedDep ??= { events: [] })
      store.reloads = (store.reloads ?? 0) + 1

      let el = document.getElementById('accepted-dep')
      if (!el) {
        el = document.createElement('div')
        el.id = 'accepted-dep'
        document.body.appendChild(el)
      }
      el.textContent = value

      import.meta.hot?.accept('./accepted_dep', (mod) => {
        store.events.push(`accepted:${mod.value}`)
        el.textContent = mod.value
      })
      """)

      write_fixture("accept_dep_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/accept_parent.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/accept_dep_page.html"), timeout: 10_000)
      {:ok, initial} = eval_poll(frame, "document.getElementById('accepted-dep')?.textContent")
      assert initial == "child-one"

      {:ok, watcher} = start_watcher()

      update_fixture("accepted_dep.ts", &String.replace(&1, "child-one", "child-two"))

      assert {:ok, "child-two"} =
               eval_until(
                 frame,
                 "document.getElementById('accepted-dep')?.textContent",
                 "child-two"
               )

      assert {:ok, true} =
               eval_until(
                 frame,
                 "window.__voltAcceptedDep.events.includes('accepted:child-two')",
                 true
               )

      {:ok, reloads} = eval_poll(frame, "window.__voltAcceptedDep.reloads")
      assert reloads == 1

      GenServer.stop(watcher)
    end

    test "parent modules accept multiple dependency updates", %{frame: frame} do
      write_fixture("multi_dep_a.ts", "export const value = 'a-one'")
      write_fixture("multi_dep_b.ts", "export const value = 'b-one'")

      write_fixture("multi_accept_parent.ts", """
      import { value as a } from './multi_dep_a'
      import { value as b } from './multi_dep_b'

      const store = (window.__voltMultiDep ??= { events: [] })
      store.reloads = (store.reloads ?? 0) + 1

      let el = document.getElementById('multi-accepted-dep')
      if (!el) {
        el = document.createElement('div')
        el.id = 'multi-accepted-dep'
        document.body.appendChild(el)
      }
      el.textContent = `${a}:${b}`

      import.meta.hot?.accept(['./multi_dep_a', './multi_dep_b'], ([modA, modB]) => {
        store.events.push(`accepted:${modA.value}:${modB.value}`)
        el.textContent = `${modA.value}:${modB.value}`
      })
      """)

      write_fixture("multi_accept_dep_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/multi_accept_parent.ts"></script>
      </body></html>
      """)

      {:ok, _} =
        Frame.goto(frame.guid, url: base_url("/multi_accept_dep_page.html"), timeout: 10_000)

      {:ok, initial} =
        eval_poll(frame, "document.getElementById('multi-accepted-dep')?.textContent")

      assert initial == "a-one:b-one"

      {:ok, watcher} = start_watcher()

      update_fixture("multi_dep_a.ts", &String.replace(&1, "a-one", "a-two"))

      assert {:ok, "a-two:b-one"} =
               eval_until(
                 frame,
                 "document.getElementById('multi-accepted-dep')?.textContent",
                 "a-two:b-one"
               )

      assert {:ok, true} =
               eval_until(
                 frame,
                 "window.__voltMultiDep.events.includes('accepted:a-two:b-one')",
                 true
               )

      {:ok, reloads} = eval_poll(frame, "window.__voltMultiDep.reloads")
      assert reloads == 1

      GenServer.stop(watcher)
    end

    test "non-accepted module updates trigger a full reload", %{frame: frame} do
      write_fixture("full_reload.ts", """
      const count = Number(sessionStorage.getItem('voltReloadCount') ?? '0') + 1
      sessionStorage.setItem('voltReloadCount', String(count))
      const el = document.createElement('div')
      el.id = 'full-reload'
      el.textContent = `before:${count}`
      document.body.appendChild(el)
      """)

      write_fixture("full_reload_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/full_reload.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/full_reload_page.html"), timeout: 10_000)
      {:ok, initial} = eval_poll(frame, "document.getElementById('full-reload')?.textContent")
      assert initial == "before:1"

      {:ok, watcher} = start_watcher()

      update_fixture("full_reload.ts", &String.replace(&1, "before", "after"))

      assert {:ok, "after:2"} =
               eval_until(frame, "document.getElementById('full-reload')?.textContent", "after:2")

      GenServer.stop(watcher)
    end

    test "CSS import HMR updates injected styles", %{frame: frame} do
      write_fixture("hmr-style.css", ".hmr-style { color: rgb(1, 2, 3); }")

      write_fixture("css_hmr.ts", """
      import './hmr-style.css'

      const count = Number(sessionStorage.getItem('voltCssReloadCount') ?? '0') + 1
      sessionStorage.setItem('voltCssReloadCount', String(count))
      const el = document.createElement('div')
      el.className = 'hmr-style'
      el.textContent = String(count)
      document.body.appendChild(el)
      """)

      write_fixture("css_hmr_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/css_hmr.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/css_hmr_page.html"), timeout: 10_000)

      {:ok, initial_color} =
        eval_poll(frame, "getComputedStyle(document.querySelector('.hmr-style')).color")

      assert initial_color == "rgb(1, 2, 3)"
      {:ok, reload_count} = eval_poll(frame, "sessionStorage.getItem('voltCssReloadCount')")
      assert reload_count == "1"

      {:ok, watcher} = start_watcher()

      update_fixture("hmr-style.css", &String.replace(&1, "rgb(1, 2, 3)", "rgb(4, 5, 6)"))

      assert {:ok, "rgb(4, 5, 6)"} =
               eval_until(
                 frame,
                 "getComputedStyle(document.querySelector('.hmr-style')).color",
                 "rgb(4, 5, 6)"
               )

      GenServer.stop(watcher)
    end

    test "imports CSS modules from JavaScript with exports and injected styles", %{frame: frame} do
      write_fixture("button.module.css", """
      .btn { color: rgb(40, 50, 60); }
      """)

      write_fixture("css_module_importer.ts", """
      import classes from './button.module.css'

      const el = document.createElement('div')
      el.className = classes.btn
      el.textContent = classes.btn
      document.body.appendChild(el)
      window.__voltCssModuleClass = classes.btn
      """)

      write_fixture("css_module_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/css_module_importer.ts"></script>
      </body></html>
      """)

      {:ok, _} = Frame.goto(frame.guid, url: base_url("/css_module_page.html"), timeout: 10_000)

      {:ok, class_name} = eval_poll(frame, "window.__voltCssModuleClass")
      assert is_binary(class_name)
      assert class_name =~ "btn"

      {:ok, style_count} =
        eval_poll(
          frame,
          "document.querySelectorAll('style[data-volt-id=\"/assets/button.module.css\"]').length"
        )

      assert style_count == 1

      {:ok, color} = eval_poll(frame, "getComputedStyle(document.querySelector('div')).color")
      assert color == "rgb(40, 50, 60)"
    end
  end

  defp eval_until(frame, expression, expected, attempts \\ 30) do
    case Frame.evaluate(frame.guid,
           expression: expression,
           is_function: false,
           arg: nil,
           timeout: 5000
         ) do
      {:ok, ^expected} ->
        {:ok, expected}

      {:ok, _other} when attempts > 0 ->
        Process.sleep(100) && eval_until(frame, expression, expected, attempts - 1)

      _ ->
        {:error, :timeout}
    end
  end

  defp eval_poll(frame, expression, attempts \\ 20) do
    case Frame.evaluate(frame.guid,
           expression: expression,
           is_function: false,
           arg: nil,
           timeout: 5000
         ) do
      {:ok, result} when result != nil ->
        {:ok, result}

      {:ok, nil} when attempts > 0 ->
        Process.sleep(100) && eval_poll(frame, expression, attempts - 1)

      _ ->
        {:error, :timeout}
    end
  end

  defp start_watcher do
    with {:ok, pid} <-
           Volt.Watcher.start_link(
             root: @fixture_dir,
             target: :es2020,
             name: String.to_atom("volt_integration_hmr_#{System.unique_integer([:positive])}")
           ) do
      Process.sleep(150)
      {:ok, pid}
    end
  end

  defp base_url(path \\ "/"), do: "http://localhost:#{@port}#{path}"

  defp write_fixture(name, content) do
    File.write!(Path.join(@fixture_dir, name), content)
  end

  defp update_fixture(name, callback) do
    path = Path.join(@fixture_dir, name)
    File.write!(path, callback.(File.read!(path)))
  end
end
