defmodule Volt.Tailwind.RuntimeTest do
  use ExUnit.Case, async: false

  @tag :tmp_dir
  test "reports imported stylesheet and transitive plugin dependencies", %{tmp_dir: root} do
    File.write!(Path.join(root, "theme.css"), "@source './pages/*.html';")
    File.write!(Path.join(root, "helper.cjs"), "module.exports = {color: 'red'}")

    File.write!(
      Path.join(root, "plugin.cjs"),
      "const value = require('./helper.cjs'); module.exports = ({addUtilities}) => addUtilities({'.custom': value})"
    )

    session = make_ref()
    runtime = Volt.Tailwind.Supervisor.runtime({:session, session, :css})
    on_exit(fn -> Volt.Tailwind.Supervisor.release_runtime(session) end)

    assert {:ok, metadata} =
             Volt.Tailwind.Runtime.compile_metadata(
               "@import './theme.css'; @plugin './plugin.cjs'; @tailwind utilities source(none);",
               ["custom"],
               root,
               runtime
             )

    assert metadata.root == :none
    assert [%Oxide.Source{pattern: "./pages/*.html"}] = metadata.sources

    for file <- ["theme.css", "plugin.cjs", "helper.cjs"] do
      assert Path.join(root, file) in metadata.dependencies
    end

    assert metadata.code =~ ".custom"
  end

  test "compiler death during a call returns an error and permits recovery" do
    session = make_ref()
    wrapper = Volt.Tailwind.Supervisor.runtime({:session, session, :css})
    on_exit(fn -> Volt.Tailwind.Supervisor.release_runtime(session) end)
    parent = self()

    {:ok, compiler} =
      QuickBEAM.start(
        handlers: %{
          "blocked" => fn [] ->
            send(parent, {:compiler_blocked, self()})

            receive do
              :release -> :ok
            end
          end
        }
      )

    # Install a controlled runtime in the wrapper to exercise the real call/exit path.
    :sys.replace_state(wrapper, fn _ -> %Volt.JS.Runtime{pid: compiler} end)
    Process.unlink(compiler)
    on_exit(fn -> if Process.alive?(compiler), do: QuickBEAM.stop(compiler) end)

    {:ok, _} =
      QuickBEAM.eval(compiler, "globalThis.compileTailwindCss = () => Beam.call('blocked')")

    task = Task.async(fn -> Volt.Tailwind.Runtime.call("", [], File.cwd!(), wrapper) end)
    assert_receive {:compiler_blocked, handler}
    Process.exit(compiler, :kill)
    send(handler, :release)
    assert {:error, {:compiler_exit, _}} = Task.await(task)
    assert Process.alive?(wrapper)

    assert {:ok, css} =
             Volt.Tailwind.Runtime.call("@tailwind utilities;", ["flex"], File.cwd!(), wrapper)

    assert css =~ ".flex"
  end

  test "session runtimes isolate compiler death and recover on the next call" do
    first = make_ref()
    second = make_ref()
    a = Volt.Tailwind.Supervisor.runtime({:session, first, :css})
    b = Volt.Tailwind.Supervisor.runtime({:session, second, :css})

    on_exit(fn ->
      Volt.Tailwind.Supervisor.release_runtime(first)
      Volt.Tailwind.Supervisor.release_runtime(second)
    end)

    refute a == b
    assert {:ok, _} = Volt.Tailwind.Runtime.call("@tailwind utilities;", ["flex"], File.cwd!(), a)
    assert {:ok, _} = Volt.Tailwind.Runtime.call("@tailwind utilities;", ["grid"], File.cwd!(), b)
    compiler = :sys.get_state(a).pid
    monitor = Process.monitor(compiler)
    Process.exit(compiler, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^compiler, :killed}

    assert {:ok, css} =
             Volt.Tailwind.Runtime.call("@tailwind utilities;", ["hidden"], File.cwd!(), a)

    assert css =~ ".hidden"
    assert Process.alive?(b)
    refute :sys.get_state(a).pid == compiler
    assert :ok = Volt.Tailwind.Supervisor.release_runtime(first)
    refute Process.alive?(a)
    assert Process.alive?(b)
  end

  test "one-shot compilation releases its linked runtime on success and compiler error" do
    {:links, before_links} = Process.info(self(), :links)
    before_links = MapSet.new(before_links)

    assert {:ok, css} =
             Volt.Tailwind.Runtime.compile_once("@tailwind utilities;", ["flex"], File.cwd!())

    assert css =~ ".flex"
    {:links, after_success} = Process.info(self(), :links)
    assert MapSet.new(after_success) == before_links

    assert {:error, _} =
             Volt.Tailwind.Runtime.compile_once(
               "@import './does-not-exist.css';",
               [],
               File.cwd!()
             )

    {:links, after_failure} = Process.info(self(), :links)
    assert MapSet.new(after_failure) == before_links
  end
end
