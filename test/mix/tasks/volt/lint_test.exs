defmodule Mix.Tasks.Volt.LintTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @tmp_dir "tmp/lint_test_#{:erlang.unique_integer([:positive])}"

  setup do
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    original_root = Application.get_env(:volt, :root)
    original_lint = Application.get_env(:volt, :lint)
    Application.put_env(:volt, :root, @tmp_dir)

    on_exit(fn ->
      if original_root,
        do: Application.put_env(:volt, :root, original_root),
        else: Application.delete_env(:volt, :root)

      if original_lint,
        do: Application.put_env(:volt, :lint, original_lint),
        else: Application.delete_env(:volt, :lint)
    end)

    :ok
  end

  test "reports no issues for clean code" do
    File.write!(Path.join(@tmp_dir, "clean.ts"), "export const x = 1;\n")
    Application.put_env(:volt, :lint, plugins: [:typescript])

    output = capture_io(fn -> Mix.Tasks.Volt.Lint.run([]) end)
    assert output =~ "No issues found"
  end

  test "detects eqeqeq violation" do
    File.write!(Path.join(@tmp_dir, "bad.js"), "export const y = x == 1;\n")
    Application.put_env(:volt, :lint, rules: %{"eqeqeq" => :deny})

    output =
      capture_io(fn ->
        catch_exit(Mix.Tasks.Volt.Lint.run([]))
      end)

    assert output =~ "eqeqeq"
    assert output =~ "error"
  end

  test "detects typescript rule" do
    File.write!(Path.join(@tmp_dir, "typed.ts"), "export function foo(x: any) { return x; }\n")

    Application.put_env(:volt, :lint,
      plugins: [:typescript],
      rules: %{"typescript/no-explicit-any" => :warn}
    )

    output = capture_io(fn -> Mix.Tasks.Volt.Lint.run([]) end)
    assert output =~ "no-explicit-any"
  end

  test "CLI --plugin flag overrides config" do
    File.write!(Path.join(@tmp_dir, "typed.ts"), "export function foo(x: any) { return x; }\n")

    Application.put_env(:volt, :lint,
      plugins: [],
      rules: %{"typescript/no-explicit-any" => :warn}
    )

    output = capture_io(fn -> Mix.Tasks.Volt.Lint.run(["--plugin", "typescript"]) end)
    assert output =~ "no-explicit-any"
  end

  test "generated filenames can be exempted without disabling filename-case elsewhere" do
    File.mkdir_p!(Path.join(@tmp_dir, "colocated/DemoWeb"))
    generated = Path.join(@tmp_dir, "colocated/DemoWeb/BadName.js")
    authored = Path.join(@tmp_dir, "BadName.js")
    for file <- [generated, authored], do: File.write!(file, "export const value = 1;\n")

    Application.put_env(:volt, :lint,
      plugins: [:unicorn],
      rules: %{"unicorn/filename-case" => :deny},
      overrides: [%{files: ["colocated/**/*.js"], rules: %{"unicorn/filename-case" => :allow}}]
    )

    assert [%{file: ^authored, rule: rule}] = Volt.JS.Check.lint([generated, authored])
    assert rule =~ "filename-case"

    output =
      capture_io(fn -> assert catch_exit(Mix.Tasks.Volt.Lint.run([])) == {:shutdown, 1} end)

    refute output =~ "colocated/DemoWeb"
    assert output =~ "BadName.js"
    assert output =~ "filename-case"
  end

  test "CLI plugins still enable rules introduced by an override" do
    File.write!(Path.join(@tmp_dir, "typed.ts"), "export function foo(x: any) { return x; }\n")

    Application.put_env(:volt, :lint,
      plugins: [],
      overrides: [%{files: ["typed.ts"], rules: %{"typescript/no-explicit-any" => :warn}}]
    )

    output = capture_io(fn -> Mix.Tasks.Volt.Lint.run(["--plugin", "typescript"]) end)
    assert output =~ "no-explicit-any"
  end

  test "applies scoped rules, environments and globals in both lint commands" do
    File.mkdir_p!(Path.join(@tmp_dir, "scripts"))
    script = Path.join(@tmp_dir, "scripts/build.js")
    browser = Path.join(@tmp_dir, "browser.js")
    File.write!(script, "process.exitCode = externalValue;\nexport const value = null;\n")
    File.write!(browser, "document.title = externalValue;\nexport const value = null;\n")

    Application.put_env(:volt, :lint,
      root: @tmp_dir,
      plugins: [:unicorn],
      env: [:browser],
      rules: %{"no-undef" => :deny, "unicorn/no-null" => :deny},
      overrides: [
        %{
          files: ["scripts/**/*.js"],
          env: %{browser: false, node: true},
          globals: %{"externalValue" => :readonly},
          rules: %{"unicorn/no-null" => :allow}
        }
      ]
    )

    diagnostics = Volt.JS.Check.lint([script, browser])
    refute Enum.any?(diagnostics, &(&1.file == script))
    assert Enum.any?(diagnostics, &(&1.file == browser and &1.rule =~ "no-null"))
    assert Enum.any?(diagnostics, &(&1.file == browser and &1.message =~ "externalValue"))

    output =
      capture_io(fn -> assert catch_exit(Mix.Tasks.Volt.Lint.run([])) == {:shutdown, 1} end)

    refute output =~ "scripts/build.js"
    assert output =~ "browser.js"
    assert output =~ "no-null"
    assert output =~ "externalValue"

    for file <- [script, browser] do
      {:ok, formatted} = OXC.Format.run(File.read!(file), file, Volt.JS.Format.load_config())
      File.write!(file, formatted)
    end

    check_output =
      capture_io(:stderr, fn ->
        capture_io(fn -> assert catch_exit(Mix.Tasks.Volt.Js.Check.run([])) == {:shutdown, 1} end)
      end)

    refute check_output =~ "scripts/build.js"
    assert check_output =~ "browser.js"
    assert check_output =~ "no-null"
    assert check_output =~ "externalValue"
  end

  test "overrides can disable inherited environments and globals" do
    file = Path.join(@tmp_dir, "server.js")
    File.write!(file, "document.title = sharedGlobal;\nprocess.exitCode = 0;\n")

    Application.put_env(:volt, :lint,
      env: [:browser],
      globals: %{"sharedGlobal" => :readonly},
      rules: %{"no-undef" => :deny},
      overrides: [
        %{
          files: ["server.js"],
          env: %{browser: false, node: true},
          globals: %{"sharedGlobal" => :off}
        }
      ]
    )

    diagnostics = Volt.JS.Check.lint([file])
    assert length(diagnostics) == 2
    assert Enum.any?(diagnostics, &(&1.message =~ "document"))
    assert Enum.any?(diagnostics, &(&1.message =~ "sharedGlobal"))
    refute Enum.any?(diagnostics, &(&1.message =~ "process"))

    output =
      capture_io(fn -> assert catch_exit(Mix.Tasks.Volt.Lint.run([])) == {:shutdown, 1} end)

    assert output =~ "document"
    assert output =~ "sharedGlobal"
    refute output =~ "process"
  end

  test "skips node_modules" do
    File.mkdir_p!(Path.join(@tmp_dir, "node_modules/pkg"))
    File.write!(Path.join([@tmp_dir, "node_modules", "pkg", "bad.js"]), "debugger;\n")
    Application.put_env(:volt, :lint, rules: %{"no-debugger" => :deny})

    output = capture_io(fn -> Mix.Tasks.Volt.Lint.run([]) end)
    assert output =~ "No lintable files"
  end

  test "reports correct file location" do
    File.write!(Path.join(@tmp_dir, "loc.js"), "const a = 1;\nexport const b = x == y;\n")
    Application.put_env(:volt, :lint, rules: %{"eqeqeq" => :deny})

    output =
      capture_io(fn ->
        catch_exit(Mix.Tasks.Volt.Lint.run([]))
      end)

    assert output =~ "loc.js:2:"
  end

  test "custom rules via config" do
    defmodule TestNoDebugger do
      @behaviour OXC.Lint.Rule

      @impl true
      def meta,
        do: %{
          name: "test/no-debugger-custom",
          description: "custom",
          category: :correctness,
          fixable: false
        }

      @impl true
      def run(ast, _ctx) do
        OXC.collect(ast, fn
          %{type: :debugger_statement, start: s, end: e} ->
            {:keep, %{span: {s, e}, message: "custom debugger ban"}}

          _ ->
            :skip
        end)
      end
    end

    File.write!(Path.join(@tmp_dir, "dbg.js"), "export function f() { debugger; }\n")
    Application.put_env(:volt, :lint, custom_rules: [{TestNoDebugger, :deny}])

    output =
      capture_io(fn ->
        catch_exit(Mix.Tasks.Volt.Lint.run([]))
      end)

    assert output =~ "custom debugger ban"
    assert output =~ "test/no-debugger-custom"
  end
end
