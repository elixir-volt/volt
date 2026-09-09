defmodule Volt.DevServer.RequestsTest do
  use Volt.TestSupport.DevServerCase

  @tag :tmp_dir
  test "session CSS links to served nested assets without rewriting stored CSS", %{tmp_dir: root} do
    session = make_ref()
    File.mkdir_p!(Path.join(root, "css/nested"))
    source = Path.join(root, "css/app.css")
    File.write!(source, "@import './nested/theme.css';")

    File.write!(
      Path.join(root, "css/nested/theme.css"),
      ".logo { background: url('./logo.svg?v=1#mark') }"
    )

    File.write!(Path.join(root, "css/nested/logo.svg"), "<svg/>")

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: session,
         watcher: [
           root: root,
           session: session,
           name: nil,
           tailwind: true,
           tailwind_css: source,
           tailwind_sources: []
         ]}
      )

    tables = Volt.Dev.Session.Supervisor.tables(supervisor)
    {:ok, stored} = Volt.Tailwind.Worker.stylesheet(tables.stylesheet_worker)

    config = %{
      Volt.DevServer.init(root: root, session: session, session_supervisor: supervisor)
      | stylesheet_url: "/assets/site.css",
        stylesheet_source: source
    }

    response = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(config)
    assert response.status == 200
    assert response.resp_body =~ "/assets/css/nested/logo.svg?v=1#mark"
    asset = Plug.Test.conn(:get, "/assets/css/nested/logo.svg?v=1") |> Volt.DevServer.call(config)
    assert asset.status == 200
    assert asset.resp_body == "<svg/>"
    assert {:ok, ^stored} = Volt.Tailwind.Worker.stylesheet(tables.stylesheet_worker)
  end

  @tag :tmp_dir
  test "serves retained CSS without a disk artifact and preserves it on compiler error", %{
    tmp_dir: root
  } do
    session = make_ref()

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: session, watcher: [root: root, session: session, name: nil, tailwind: false]}
      )

    {_, worker, _, _} =
      Enum.find(Supervisor.which_children(supervisor), fn {id, _, _, _} ->
        id == Volt.Tailwind.Worker
      end)

    assert {:ok, css} =
             Volt.Tailwind.build(worker: worker, css: ".retained { color: red }", sources: [])

    config = %{
      Volt.DevServer.init(root: root, session: session, session_supervisor: supervisor)
      | stylesheet_url: "/assets/site.css"
    }

    response = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(config)
    assert response.status == 200
    assert response.resp_body == css
    assert Plug.Conn.get_resp_header(response, "content-type") == ["text/css; charset=utf-8"]
    refute File.exists?(Path.join(root, "site.css"))

    assert {:error, _} =
             Volt.Tailwind.build(
               worker: worker,
               css: "@import './missing.css';",
               css_base: root,
               sources: []
             )

    response = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(config)
    assert response.resp_body == css
  end

  defmodule PausedCompiler do
    @behaviour Volt.Plugin
    def name, do: "paused-compiler"

    def compile(_path, _source, _opts, parent: parent) do
      send(parent, {:compiling, self()})

      receive do
        :continue -> {:ok, %Volt.Pipeline.Result{code: "console.log('compiled')", type: :js}}
      end
    end
  end

  @tag :tmp_dir
  test "restart during compilation cannot populate the replacement generation", %{tmp_dir: root} do
    File.write!(Path.join(root, "app.ts"), "console.log('source')")
    session = make_ref()

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: session, watcher: [root: root, session: session, name: nil, tailwind: false]}
      )

    config =
      Volt.DevServer.init(
        root: root,
        session: session,
        session_supervisor: supervisor,
        plugins: [{PausedCompiler, [parent: self()]}]
      )

    old = Volt.Dev.Session.Supervisor.tables(supervisor)

    request =
      Task.async(fn -> Plug.Test.conn(:get, "/assets/app.ts") |> Volt.DevServer.call(config) end)

    assert_receive {:compiling, compiling}
    monitor = Process.monitor(old.owner)
    Process.exit(old.owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}
    current = Volt.Dev.Session.Supervisor.tables(supervisor)
    refute current.generation == old.generation
    send(compiling, :continue)
    assert Task.await(request).status == 503
    assert Volt.Cache.get_file(Path.join(root, "app.ts"), current) == nil

    fresh =
      Task.async(fn -> Plug.Test.conn(:get, "/assets/app.ts") |> Volt.DevServer.call(config) end)

    assert_receive {:compiling, compiling}
    send(compiling, :continue)
    assert Task.await(fresh).status == 200
    assert Volt.Cache.get_file(Path.join(root, "app.ts"), current)
  end

  @tag :tmp_dir
  test "stale generation handles return a retryable response", %{tmp_dir: root} do
    File.write!(Path.join(root, "app.ts"), "console.log('stale')")
    owner = start_supervised!(Volt.Dev.Session.State)
    tables = Volt.Dev.Session.State.tables(owner)
    config = Volt.DevServer.init(root: root, tables: tables, watch: false)
    stop_supervised!(Volt.Dev.Session.State)
    conn = Plug.Test.conn(:get, "/assets/app.ts") |> Volt.DevServer.call(config)
    assert conn.status == 503
    assert conn.halted
    assert conn.resp_body =~ "retry"
  end

  @tag :tmp_dir
  test "automatic managed sessions serve identical URLs from distinct owned generations", %{
    tmp_dir: root
  } do
    sessions =
      for label <- ["first", "second"] do
        directory = Path.join(root, label)
        File.mkdir_p!(directory)
        File.write!(Path.join(directory, "app.ts"), "console.log('#{label}')")
        session = make_ref()
        on_exit(fn -> Volt.Dev.stop(session) end)
        {session, directory, Volt.DevServer.init(root: directory, session: session, watch: true)}
      end

    for {session, directory, config} <- sessions do
      conn = Plug.Test.conn(:get, "/assets/app.ts") |> Volt.DevServer.call(config)
      assert conn.status == 200
      assert conn.resp_body =~ Path.basename(directory)
      tables = Volt.Dev.tables(session)
      assert Volt.Cache.get_file(Path.join(directory, "app.ts"), tables)
      assert Volt.Cache.get_file(Path.join(directory, "app.ts"), session) == nil
    end

    [{first, _, config}, {second, _, _}] = sessions
    first_tables = Volt.Dev.tables(first)
    second_tables = Volt.Dev.tables(second)
    refute first_tables.owner == second_tables.owner
    assert :ok = Volt.Dev.stop(first)
    assert :ets.info(first_tables.cache) == :undefined
    assert :ets.info(second_tables.cache, :owner) == second_tables.owner

    assert Plug.Test.conn(:get, "/assets/app.ts")
           |> Volt.DevServer.call(config)
           |> Map.fetch!(:status) == 200

    refute Volt.Dev.tables(first).generation == first_tables.generation
  end

  @tag :tmp_dir
  test "requests share owned tables with their sole watcher", %{tmp_dir: root} do
    session = make_ref()
    File.write!(Path.join(root, "app.ts"), "console.log('owned request')")

    supervisor =
      start_supervised!(
        {Volt.Dev.Session.Supervisor,
         identity: session, watcher: [root: root, session: session, name: nil, tailwind: false]}
      )

    config = Volt.DevServer.init(root: root, session: session, session_supervisor: supervisor)
    assert config.watcher_opts == nil
    conn = Plug.Test.conn(:get, "/assets/app.ts") |> Volt.DevServer.call(config)
    assert conn.status == 200
    assert conn.resp_body =~ "owned request"
    tables = Volt.Dev.Session.Supervisor.tables(supervisor)
    assert Volt.Cache.get_file(Path.join(root, "app.ts"), tables)
    assert Volt.Cache.get_file(Path.join(root, "app.ts"), session) == nil
    assert [_] = Volt.HMR.ModuleGraph.get_by_file(Path.join(root, "app.ts"), tables)
    assert Volt.HMR.ModuleGraph.get_by_file(Path.join(root, "app.ts"), session) == []
  end

  describe "non-matching paths" do
    test "passes through non-matching prefix" do
      conn = call_dev_server("/other/app.ts")
      refute conn.halted
    end

    test "serves static assets with correct MIME type" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "image/png"
    end

    test "serves asset imports as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?import")
      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/png;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves raw asset query as a JavaScript string module" do
      File.write!(Path.join(@fixture_dir, "src/data.txt"), "hello\nworld")
      conn = call_dev_server("/assets/data.txt?raw")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "hello\\nworld";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves URL asset query as a JavaScript URL module" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?url")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves asset script fetches as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/icon.svg"), "<svg></svg>")

      opts = Volt.DevServer.init(root: Path.join(@fixture_dir, "src"), prefix: "/assets")

      conn =
        conn(:get, "/assets/icon.svg")
        |> put_req_header("sec-fetch-dest", "script")
        |> Volt.DevServer.call(opts)

      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/svg+xml;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves large asset imports with their dev URL" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/image.png"), String.duplicate("x", 4097))
      conn = call_dev_server("/assets/images/image.png?import")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/images/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "passes through unknown extensions" do
      File.write!(Path.join(@fixture_dir, "src/data.xyz"), "binary")
      conn = call_dev_server("/assets/data.xyz")
      refute conn.halted
    end

    test "passes through missing files" do
      conn = call_dev_server("/assets/missing.ts")
      refute conn.halted
    end
  end

  describe "error handling" do
    test "returns 500 with error overlay for invalid source" do
      File.write!(Path.join(@fixture_dir, "src/bad.ts"), "const = ;")
      conn = call_dev_server("/assets/bad.ts")
      assert conn.status == 500
      assert conn.resp_body =~ "renderErrorOverlay"
      assert conn.resp_body =~ "Compilation error"
    end
  end
end
