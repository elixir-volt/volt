defmodule Volt.Tailwind.WorkerTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  test "changed source directives reconstruct scanning without retaining old discovered roots", %{
    tmp_dir: tmp
  } do
    key = {:test, make_ref()}
    on_exit(fn -> Volt.Tailwind.Supervisor.release(key) end)
    File.mkdir_p!(Path.join(tmp, "first"))
    File.mkdir_p!(Path.join(tmp, "second"))
    File.write!(Path.join(tmp, "first/page.html"), "<div class='flex'></div>")
    File.write!(Path.join(tmp, "second/page.html"), "<div class='grid'></div>")
    first_css = "@tailwind utilities source(none); @source './first/*.html';"
    second_css = "@tailwind utilities source(none); @source './second/*.html';"

    assert {:ok, first} =
             Volt.Tailwind.build(key: key, css: first_css, css_base: tmp, sources: [])

    assert first =~ ".flex"
    assert {:ok, second} = Volt.Tailwind.rebuild([], key: key, css: second_css)
    assert second =~ ".grid"
    refute second =~ ".flex"
    assert {:ok, rebuilt} = Volt.Tailwind.build(key: key, css: second_css, css_base: tmp)
    refute rebuilt =~ ".flex"
  end

  test "recovers a dead context without new candidates and releases it on shutdown", %{
    tmp_dir: tmp
  } do
    key = {:test, make_ref()}
    on_exit(fn -> Volt.Tailwind.Supervisor.release(key) end)
    File.write!(Path.join(tmp, "page.html"), "<div class='flex'></div>")

    assert {:ok, first} =
             Volt.Tailwind.build(
               key: key,
               css: "@tailwind utilities;",
               sources: [%{base: tmp, pattern: "*.html"}]
             )

    [{worker, _}] = Registry.lookup(Volt.Tailwind.Registry, key)
    old = :sys.get_state(worker).context
    monitor = Process.monitor(old.runtime)
    Process.exit(old.runtime, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}
    assert :unchanged = Volt.Tailwind.rebuild([], key: key)
    state = :sys.get_state(worker)
    refute state.context.runtime == old.runtime
    assert {:ok, ^first} = Volt.Tailwind.Worker.stylesheet(worker)
    assert :ok = Volt.Tailwind.Supervisor.release(key)
    assert {:error, _} = Volt.Tailwind.Runtime.build_context(state.context, [], state.runtime)
    assert GenServer.whereis(state.runtime)
  end

  test "candidate-only rebuild retains custom CSS and base directory", %{tmp_dir: tmp} do
    key = {:test, make_ref()}
    on_exit(fn -> Volt.Tailwind.Supervisor.release(key) end)
    File.write!(Path.join(tmp, "theme.css"), ".retained { color: red }")
    File.write!(Path.join(tmp, "page.html"), ~s(<p class="flex"></p>))

    assert {:ok, first} =
             Volt.Tailwind.build(
               key: key,
               css: "@import './theme.css'; @tailwind utilities;",
               css_base: tmp,
               minify: true,
               sources: [%{base: tmp, pattern: "*.html"}]
             )

    assert first =~ ".retained"
    File.write!(Path.join(tmp, "page.html"), ~s(<p class="flex grid"></p>))
    assert {:ok, rebuilt} = Volt.Tailwind.rebuild([Path.join(tmp, "page.html")], key: key)
    assert rebuilt =~ ".retained"
    assert rebuilt =~ ".grid"
    assert [{pid, _}] = Registry.lookup(Volt.Tailwind.Registry, key)
    assert :sys.get_state(pid).compilation.minify
  end

  test "isolates scanner state by build context", %{tmp_dir: tmp} do
    first = Path.join(tmp, "first")
    second = Path.join(tmp, "second")
    File.mkdir_p!(first)
    File.mkdir_p!(second)
    File.write!(Path.join(first, "page.html"), ~S|<p class="grid"></p>|)
    File.write!(Path.join(second, "page.html"), ~S|<p class="flex"></p>|)

    assert {:ok, first_css} =
             Volt.Tailwind.build(
               key: {:test, make_ref()},
               sources: [%{base: first, pattern: "**/*.html"}]
             )

    assert {:ok, second_css} =
             Volt.Tailwind.build(
               key: {:test, make_ref()},
               sources: [%{base: second, pattern: "**/*.html"}]
             )

    assert first_css =~ ".grid"
    refute first_css =~ ".flex"
    assert second_css =~ ".flex"
    refute second_css =~ ".grid"
  end

  test "root workers share one compiler runtime" do
    first_key = {:test, make_ref()}
    second_key = {:test, make_ref()}

    assert {:ok, _css} = Volt.Tailwind.build(key: first_key, sources: [])
    runtime_pid = Process.whereis(Volt.Tailwind.Runtime)
    assert is_pid(runtime_pid)

    assert {:ok, _css} = Volt.Tailwind.build(key: second_key, sources: [])
    assert Process.whereis(Volt.Tailwind.Runtime) == runtime_pid
    assert Process.alive?(runtime_pid)

    assert [{first_worker, _}] = Registry.lookup(Volt.Tailwind.Registry, first_key)
    assert [{second_worker, _}] = Registry.lookup(Volt.Tailwind.Registry, second_key)
    assert first_worker != second_worker
  end

  test "rebuild returns unchanged when generated CSS is identical", %{tmp_dir: tmp} do
    key = {:test, make_ref()}
    File.write!(Path.join(tmp, "page.html"), ~S|<p class="grid"></p>|)

    assert {:ok, _css} =
             Volt.Tailwind.build(
               key: key,
               sources: [%{base: tmp, pattern: "**/*.html"}]
             )

    assert :unchanged =
             Volt.Tailwind.rebuild(
               [%{content: ~S|<p class="grid"></p>|, extension: "html"}],
               key: key
             )
  end
end
