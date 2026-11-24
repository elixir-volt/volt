defmodule Volt.Integration.TestPlug do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  # Pages rendered from content files, sent through the dev server as an app's
  # own pages are.
  def call(%Conn{request_path: "/doc/" <> name} = conn, opts),
    do: document(conn, name, opts[:root], opts[:dev_server])

  def call(%Conn{request_path: "/morph/" <> name} = conn, opts),
    do: document(conn, name, opts[:root], opts[:morph_dev_server])

  # A page the server can render outside a request, so the page's websocket
  # process compares renders and pushes what changed.
  def call(%Conn{request_path: "/push/" <> _name = path} = conn, opts) do
    {:ok, html} = render(path, opts[:root])

    conn
    |> Volt.DevServer.call(opts[:push_dev_server])
    |> Conn.put_resp_content_type("text/html")
    |> Conn.send_resp(200, html)
  end

  # Every page shares one websocket endpoint, served by the dev server that can
  # render documents; it only knows the `/push/` pages.
  def call(%Conn{request_path: "/@volt/ws"} = conn, opts),
    do: Volt.DevServer.call(conn, opts[:push_dev_server])

  def call(conn, opts), do: asset(conn, opts)

  def render("/push/" <> name, root) do
    [text, props, lang, description] =
      Path.join(root <> "-content", name <> ".md") |> File.read!() |> String.split("|")

    {:ok,
     """
     <!DOCTYPE html>
     <html lang="#{lang}"><head><title>#{name}</title>
     <meta name="description" content="#{description}">
     </head><body>
       <div id="content">#{text}</div>
       <div id="owned" data-owned data-props="#{props}"></div>
       <script>
         const loads = Number(sessionStorage.getItem('voltPushLoads') ?? '0') + 1
         sessionStorage.setItem('voltPushLoads', String(loads))
         document.body.dataset.loads = String(loads)
         document.documentElement.dataset.theme = 'dark'
         const owned = document.getElementById('owned')
         owned.textContent = 'props:' + owned.dataset.props
         owned.addEventListener('volt:element-update', (event) => {
           event.preventDefault()
           owned.textContent = 'props:' + owned.dataset.props
         })
       </script>
     </body></html>
     """}
  end

  def render(_path, _root), do: :error

  defp document(conn, name, root, dev_server) do
    content = File.read!(Path.join(root <> "-content", name <> ".md"))

    conn
    |> Volt.DevServer.call(dev_server)
    |> Conn.put_resp_content_type("text/html")
    |> Conn.send_resp(200, """
    <!DOCTYPE html>
    <html><head><title>#{name}</title></head><body>
      <div id="content">#{content}</div>
      <script>
        const loads = Number(sessionStorage.getItem('voltDocLoads') ?? '0') + 1
        sessionStorage.setItem('voltDocLoads', String(loads))
        document.body.dataset.loads = String(loads)
      </script>
    </body></html>
    """)
  end

  defp asset(conn, opts) do
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
  use Playwright.Case, async: false

  @moduletag :integration

  @fixture_dir Path.join(System.tmp_dir!(), "volt-integration-hmr-test")
  @port 44_831

  setup do
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
    morph_opts = Volt.DevServer.init(root: @fixture_dir, prefix: "/assets", morph: true)

    push_opts =
      Volt.DevServer.init(
        root: @fixture_dir,
        prefix: "/assets",
        morph: [preserve: "[data-owned]"],
        document: {Volt.Integration.TestPlug, :render, [@fixture_dir]}
      )

    plug_opts = %{
      root: @fixture_dir,
      dev_server: dev_server_opts,
      morph_dev_server: morph_opts,
      push_dev_server: push_opts
    }

    {:ok, server} =
      Bandit.start_link(
        plug: {Volt.Integration.TestPlug, plug_opts},
        port: @port,
        ip: :loopback,
        startup_log: false
      )

    on_exit(fn ->
      Process.exit(server, :normal)
      File.rm_rf!(@fixture_dir)
    end)
  end

  describe "dev server module serving" do
    test "serves compiled TypeScript and executes in browser", %{page: page} do
      {:ok, _} = Page.goto(page, base_url(), timeout: 10_000)

      {:ok, _handle} =
        Page.wait_for_function(page, "document.getElementById('volt-test')?.textContent", nil,
          timeout: 5000
        )
    end

    test "injects import.meta.hot into served modules", %{page: page} do
      write_fixture("hot_check.ts", """
      window.__voltHotAvailable = typeof import.meta.hot?.accept === 'function'
      """)

      write_fixture("hot_page.html", """
      <!DOCTYPE html>
      <html><body>
        <script type="module" src="/assets/hot_check.ts"></script>
      </body></html>
      """)

      {:ok, _} = Page.goto(page, base_url("/hot_page.html"), timeout: 10_000)

      expect_eval(page, "window.__voltHotAvailable", true)
    end

    test "rewrites relative imports between modules", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/import_page.html"), timeout: 10_000)

      expect_eval(page, "window.__voltImportResult", "hello from utils")
    end

    test "imports CSS from JavaScript and injects a style tag", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/css_import_page.html"), timeout: 10_000)

      expect_eval(page, "window.__voltCssImportLoaded", true)

      Expect.to_have_count!(Page.locator(page, "style[data-volt-id=\"/assets/imported.css\"]"), 1)

      Expect.to_have_css!(
        Page.locator(page, ".volt-css-import-target"),
        "color",
        "rgb(10, 20, 30)"
      )
    end

    test "self-accepting modules update without reloading and preserve hot data", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/self_accept_page.html"), timeout: 10_000)
      Expect.to_have_text!(Page.locator(page, "#self-accept"), "one:none")

      {:ok, watcher} = start_watcher()

      update_fixture("self_accept.ts", &String.replace(&1, "'one'", "'two'"))

      Expect.to_have_text!(Page.locator(page, "#self-accept"), "two:one")

      expect_eval(
        page,
        "window.__voltSelfAccept.events.includes('dispose:one') && window.__voltSelfAccept.events.includes('accept:two')",
        true
      )

      GenServer.stop(watcher)
    end

    test "parent modules accept dependency updates without reloading", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/accept_dep_page.html"), timeout: 10_000)
      Expect.to_have_text!(Page.locator(page, "#accepted-dep"), "child-one")

      {:ok, watcher} = start_watcher()

      update_fixture("accepted_dep.ts", &String.replace(&1, "child-one", "child-two"))

      Expect.to_have_text!(Page.locator(page, "#accepted-dep"), "child-two")

      expect_eval(page, "window.__voltAcceptedDep.events.includes('accepted:child-two')", true)

      expect_eval(page, "window.__voltAcceptedDep.reloads", 1)

      GenServer.stop(watcher)
    end

    test "parent modules accept multiple dependency updates", %{page: page} do
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
        Page.goto(page, base_url("/multi_accept_dep_page.html"), timeout: 10_000)

      Expect.to_have_text!(Page.locator(page, "#multi-accepted-dep"), "a-one:b-one")

      {:ok, watcher} = start_watcher()

      update_fixture("multi_dep_a.ts", &String.replace(&1, "a-one", "a-two"))

      Expect.to_have_text!(Page.locator(page, "#multi-accepted-dep"), "a-two:b-one")

      expect_eval(page, "window.__voltMultiDep.events.includes('accepted:a-two:b-one')", true)

      expect_eval(page, "window.__voltMultiDep.reloads", 1)

      GenServer.stop(watcher)
    end

    test "content changes reload only the pages whose HTML changed", %{page: page} do
      # Content lives beside the asset root, as a site's pages and posts do.
      content_dir = @fixture_dir <> "-content"
      File.rm_rf!(content_dir)
      File.mkdir_p!(content_dir)
      on_exit(fn -> File.rm_rf!(content_dir) end)
      File.write!(Path.join(content_dir, "first.md"), "first page")
      File.write!(Path.join(content_dir, "second.md"), "second page")

      {:ok, _} = Page.goto(page, base_url("/doc/first"), timeout: 10_000)
      Expect.to_have_attribute!(Page.locator(page, "body"), "data-loads", "1")

      {:ok, watcher} =
        Volt.Watcher.start_link(
          root: @fixture_dir,
          reload_dirs: [content_dir],
          name: String.to_atom("volt_integration_doc_#{System.unique_integer([:positive])}")
        )

      Process.sleep(150)

      # Another page's content: this page revalidates and stays.
      File.write!(Path.join(content_dir, "second.md"), "second page, edited")
      Process.sleep(1000)
      Expect.to_have_attribute!(Page.locator(page, "body"), "data-loads", "1")

      Expect.to_have_text!(Page.locator(page, "#content"), "first page")

      File.write!(Path.join(content_dir, "first.md"), "first page, edited")

      Expect.to_have_text!(Page.locator(page, "#content"), "first page, edited")

      Expect.to_have_attribute!(Page.locator(page, "body"), "data-loads", "2")

      GenServer.stop(watcher)
    end

    test "pages that opt in are patched in place instead of reloaded", %{page: page} do
      content_dir = @fixture_dir <> "-content"
      File.rm_rf!(content_dir)
      File.mkdir_p!(content_dir)
      on_exit(fn -> File.rm_rf!(content_dir) end)
      File.write!(Path.join(content_dir, "first.md"), "first page")

      {:ok, _} = Page.goto(page, base_url("/morph/first"), timeout: 10_000)
      expect_eval(page, "document.body.dataset.loads", "1")

      # State a reload would lose.
      Page.evaluate!(page, "window.voltKept = 'kept'")

      {:ok, watcher} =
        Volt.Watcher.start_link(
          root: @fixture_dir,
          reload_dirs: [content_dir],
          name: String.to_atom("volt_integration_morph_#{System.unique_integer([:positive])}")
        )

      Process.sleep(150)
      File.write!(Path.join(content_dir, "first.md"), "first page, edited")

      Expect.to_have_text!(Page.locator(page, "#content"), "first page, edited")

      expect_eval(page, "window.voltKept", "kept")
      expect_eval(page, "document.body.dataset.loads", "1")

      # The patched page revalidates against its new HTML.
      File.write!(Path.join(content_dir, "first.md"), "first page, edited twice")

      Expect.to_have_text!(Page.locator(page, "#content"), "first page, edited twice")

      expect_eval(page, "window.voltKept", "kept")

      GenServer.stop(watcher)
    end

    test "the server pushes what it changed to a page it keeps a render of", %{page: page} do
      content_dir = @fixture_dir <> "-content"
      File.rm_rf!(content_dir)
      File.mkdir_p!(content_dir)
      on_exit(fn -> File.rm_rf!(content_dir) end)
      File.write!(Path.join(content_dir, "page.md"), "first|1|en|old description")

      {:ok, _} = Page.goto(page, base_url("/push/page"), timeout: 10_000)
      expect_eval(page, "document.body.dataset.loads", "1")
      Page.evaluate!(page, "window.voltKept = 'kept'")

      # The page requests nothing more: what changed arrives over the websocket.
      Page.evaluate!(
        page,
        "(window.voltFetches = 0, window.fetch = ((f) => (...a) => (window.voltFetches++, f(...a)))(window.fetch), 0)"
      )

      {:ok, watcher} =
        Volt.Watcher.start_link(
          root: @fixture_dir,
          reload_dirs: [content_dir],
          name: String.to_atom("volt_integration_push_#{System.unique_integer([:positive])}")
        )

      Process.sleep(150)
      File.write!(Path.join(content_dir, "page.md"), "second|2|ru|new description")

      Expect.to_have_text!(Page.locator(page, "#content"), "second")

      # The owner of the element re-rendered it from the props the server changed.
      Expect.to_have_text!(Page.locator(page, "#owned"), "props:2")

      # Attributes the server changed are applied; one a script set stays.
      Expect.to_have_attribute!(Page.locator(page, "html"), "lang", "ru")
      Expect.to_have_attribute!(Page.locator(page, "html"), "data-theme", "dark")

      Expect.to_have_attribute!(
        Page.locator(page, "meta[name=description]"),
        "content",
        "new description"
      )

      Expect.to_have_count!(Page.locator(page, "meta[name=description]"), 1)

      expect_eval(page, "window.voltKept", "kept")
      expect_eval(page, "document.body.dataset.loads", "1")
      expect_eval(page, "window.voltFetches", 0)

      GenServer.stop(watcher)
    end

    test "non-accepted module updates trigger a full reload", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/full_reload_page.html"), timeout: 10_000)
      Expect.to_have_text!(Page.locator(page, "#full-reload"), "before:1")

      {:ok, watcher} = start_watcher()

      update_fixture("full_reload.ts", &String.replace(&1, "before", "after"))

      Expect.to_have_text!(Page.locator(page, "#full-reload"), "after:2")

      GenServer.stop(watcher)
    end

    test "CSS import HMR updates injected styles", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/css_hmr_page.html"), timeout: 10_000)

      Expect.to_have_css!(Page.locator(page, ".hmr-style"), "color", "rgb(1, 2, 3)")
      expect_eval(page, "sessionStorage.getItem('voltCssReloadCount')", "1")

      {:ok, watcher} = start_watcher()

      update_fixture("hmr-style.css", &String.replace(&1, "rgb(1, 2, 3)", "rgb(4, 5, 6)"))

      Expect.to_have_css!(Page.locator(page, ".hmr-style"), "color", "rgb(4, 5, 6)")

      GenServer.stop(watcher)
    end

    test "imports CSS modules from JavaScript with exports and injected styles", %{page: page} do
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

      {:ok, _} = Page.goto(page, base_url("/css_module_page.html"), timeout: 10_000)

      Expect.poll!(
        fn -> Page.evaluate!(page, "window.__voltCssModuleClass") end,
        &assert(is_binary(&1) and &1 =~ "btn")
      )

      Expect.to_have_count!(
        Page.locator(page, "style[data-volt-id=\"/assets/button.module.css\"]"),
        1
      )

      Expect.to_have_css!(
        Page.locator(page, "div") |> Locator.first(),
        "color",
        "rgb(40, 50, 60)"
      )
    end
  end

  defp expect_eval(page, expression, expected) do
    Expect.poll!(fn -> Page.evaluate!(page, expression) end, &assert(&1 == expected))
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
