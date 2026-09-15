defmodule Mix.Tasks.Volt.Js.CheckTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @tmp_dir "tmp/js_check_test_#{:erlang.unique_integer([:positive])}"

  setup do
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    original_root = Application.get_env(:volt, :root)
    original_lint = Application.get_env(:volt, :lint)
    original_sources = Application.get_env(:volt, :sources)
    Application.put_env(:volt, :root, @tmp_dir)

    on_exit(fn ->
      if original_root,
        do: Application.put_env(:volt, :root, original_root),
        else: Application.delete_env(:volt, :root)

      if original_lint,
        do: Application.put_env(:volt, :lint, original_lint),
        else: Application.delete_env(:volt, :lint)

      if original_sources,
        do: Application.put_env(:volt, :sources, original_sources),
        else: Application.delete_env(:volt, :sources)
    end)

    :ok
  end

  test "reports parser errors in syntax lint mode" do
    File.write!(Path.join(@tmp_dir, "broken.ts"), "const = ;\n")

    output =
      capture_io(:stderr, fn ->
        catch_exit(Mix.Tasks.Volt.Js.Check.run([]))
      end)

    assert output =~ "error"
    assert output =~ "broken.ts"
  end

  test "syntax lint recognizes configured globals" do
    file = Path.join(@tmp_dir, "globals.js")
    File.write!(file, "document; describe; knownGlobal(); missingGlobal();\n")

    Application.put_env(:volt, :lint,
      env: [:browser, :mocha],
      globals: %{"knownGlobal" => :readonly},
      rules: %{"no-undef" => :deny}
    )

    diagnostics = Volt.JS.Check.lint([file])

    assert Enum.any?(diagnostics, &(&1.message =~ "missingGlobal"))
    refute Enum.any?(diagnostics, &(&1.message =~ "document"))
    refute Enum.any?(diagnostics, &(&1.message =~ "describe"))
    refute Enum.any?(diagnostics, &(&1.message =~ "knownGlobal"))
  end

  test "type-aware check reports tsgolint diagnostics" do
    File.write!(Path.join(@tmp_dir, "typed.ts"), "export const value = Promise.resolve(1)\n")
    tsgolint = fake_tsgolint!(@tmp_dir)

    Application.put_env(:volt, :lint,
      tsgolint: tsgolint,
      rules: %{"typescript/no-floating-promises" => :deny}
    )

    output =
      capture_io(:stderr, fn ->
        catch_exit(Mix.Tasks.Volt.Js.Check.run(["--type-aware"]))
      end)

    assert output =~ "floating promise"
    assert output =~ "typescript/no-floating-promises"
  end

  test "category-only configuration submits semantic rules to tsgolint" do
    file = Path.join(@tmp_dir, "typed.ts")
    File.write!(file, "Promise.resolve(1);\n")

    Application.put_env(:volt, :lint,
      tsgolint: fake_tsgolint!(@tmp_dir),
      plugins: [:typescript],
      rules: %{"correctness" => :deny}
    )

    diagnostics = Volt.JS.Check.lint([file], type_aware: true)

    assert Enum.any?(
             diagnostics,
             &(&1.rule == "typescript/no-floating-promises" and &1.severity == :deny)
           )
  end

  test "category expansion honors per-file semantic rule exclusions" do
    first = Path.join(@tmp_dir, "first.ts")
    second = Path.join(@tmp_dir, "second.ts")
    Enum.each([first, second], &File.write!(&1, "Promise.resolve(1);\n"))
    payload_path = Path.join(@tmp_dir, "categories.jsonl")

    tsgolint =
      fake_executable!(@tmp_dir, "tsgolint-categories", """
      input = IO.binread(:stdio, :eof)
      File.write!(#{inspect(payload_path)}, [input, "\\n"], [:append])
      """)

    Application.put_env(:volt, :lint,
      root: @tmp_dir,
      tsgolint: tsgolint,
      plugins: [:typescript],
      rules: %{"correctness" => :deny},
      overrides: [%{files: ["second.ts"], rules: %{"typescript/no-floating-promises" => :allow}}]
    )

    assert [] = Volt.JS.Check.lint([first, second], type_aware: true)
    batches = payload_path |> File.stream!() |> Enum.map(&Jason.decode!/1)
    configs = Enum.flat_map(batches, & &1["configs"])

    for {file, selected} <- [{first, true}, {second, false}] do
      config = Enum.find(configs, &(Path.expand(file) in &1["file_paths"]))
      assert Enum.any?(config["rules"], &(&1["name"] == "no-floating-promises")) == selected
    end
  end

  test "type-check diagnostics are promoted to errors" do
    diagnostic = %{
      rule: "typescript/TS2322",
      severity: :warn,
      file: "typed.ts",
      message: "Type number is not assignable to type string."
    }

    assert %{severity: :deny} =
             Volt.JS.Check.promote_type_check_diagnostic(diagnostic, type_check: true)
  end

  test "type-aware check keeps Oxlint-style rules and retries without unsupported tsgolint rules" do
    File.write!(Path.join(@tmp_dir, "typed.ts"), "export const value = 1\n")
    tsgolint = fake_tsgolint_unknown_retry!(@tmp_dir)

    Application.put_env(:volt, :lint,
      tsgolint: tsgolint,
      rules: %{
        "correctness" => :deny,
        "suspicious" => :deny,
        "no-console" => :warn,
        "typescript/consistent-type-imports" => :deny,
        "typescript/no-floating-promises" => :warn
      }
    )

    capture_io(fn ->
      Mix.Tasks.Volt.Js.Check.run(["--type-aware"])
    end)

    payload = @tmp_dir |> Path.join("payload.json") |> File.read!() |> Jason.decode!()
    assert [%{"rules" => rules}] = payload["configs"]
    assert Enum.any?(rules, &(&1["name"] == "no-floating-promises"))

    refute Enum.any?(
             rules,
             &(&1["name"] in ["correctness", "suspicious", "consistent-type-imports"])
           )
  end

  test "type-aware check submits framework single-file component scripts as virtual files" do
    File.write!(Path.join(@tmp_dir, "app.ts"), "import './Component.vue'\n")

    File.write!(
      Path.join(@tmp_dir, "Component.vue"),
      "<script setup lang=\"ts\">const vueValue: string = 'ok'</script>\n"
    )

    File.write!(
      Path.join(@tmp_dir, "Widget.svelte"),
      "<script lang=\"ts\">const svelteValue: string = 'ok'</script>\n"
    )

    tsgolint = fake_tsgolint_capture!(@tmp_dir)

    Application.put_env(:volt, :sources, ["**/*.{js,ts,jsx,tsx,vue,svelte}"])

    Application.put_env(:volt, :lint,
      tsgolint: tsgolint,
      rules: %{"typescript/no-floating-promises" => :deny}
    )

    capture_io(fn ->
      Mix.Tasks.Volt.Js.Check.run(["--type-aware"])
    end)

    payload = @tmp_dir |> Path.join("payload.json") |> File.read!() |> Jason.decode!()
    assert [%{"file_paths" => file_paths}] = payload["configs"]
    basenames = Enum.map(file_paths, &Path.basename/1)

    assert "app.ts" in basenames
    assert "Component.vue.script0.ts" in basenames
    assert "Widget.svelte.script0.ts" in basenames

    overrides = payload["source_overrides"]
    assert overrides[Path.expand(Path.join(@tmp_dir, "Component.vue.script0.ts"))] =~ "vueValue"

    assert overrides[Path.expand(Path.join(@tmp_dir, "Widget.svelte.script0.ts"))] =~
             "svelteValue"
  end

  test "type-aware overrides batch by effective rules and use original SFC paths" do
    files = Enum.map(["app.ts", "Component.vue", "Widget.svelte"], &Path.join(@tmp_dir, &1))
    [app, vue, svelte] = files
    File.write!(app, "export const value = 1;\n")
    File.write!(vue, "<script setup lang=\"ts\">const vueValue = 1</script>\n")
    File.write!(svelte, "<script lang=\"ts\">const svelteValue = 1</script>\n")
    payload_path = Path.join(@tmp_dir, "batches.jsonl")

    tsgolint =
      fake_executable!(@tmp_dir, "tsgolint-batches", """
      input = IO.binread(:stdio, :eof)
      File.write!(#{inspect(payload_path)}, [input, "\\n"], [:append])
      payload = JSON.decode!(input)
      for config <- payload["configs"], file <- config["file_paths"] do
        json = JSON.encode!(%{rule: "no-floating-promises", message: %{description: "batch diagnostic"}, file_path: file, range: %{pos: 0, end: 1}})
        IO.binwrite(<<byte_size(json)::32-little, 1, json::binary>>)
      end
      """)

    Application.put_env(:volt, :lint,
      root: @tmp_dir,
      tsgolint: tsgolint,
      rules: %{"correctness" => :deny, "typescript/no-floating-promises" => :deny},
      overrides: [
        %{files: ["**/*.{vue,svelte}"], rules: %{"typescript/no-floating-promises" => :warn}},
        %{files: ["**/*.script0.ts"], rules: %{"typescript/no-floating-promises" => :allow}}
      ]
    )

    diagnostics = Volt.JS.Check.lint(files, type_aware: true)

    assert Enum.sort(Enum.map(diagnostics, & &1.file)) ==
             Enum.sort([Path.expand(app), vue, svelte])

    batches =
      payload_path |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)

    assert length(batches) == 2

    configs = Enum.flat_map(batches, & &1["configs"])
    assert Enum.sort(Enum.map(configs, &length(&1["file_paths"]))) == [1, 2]

    names = configs |> Enum.flat_map(& &1["rules"]) |> Enum.map(& &1["name"])
    assert "no-floating-promises" in names
    refute "correctness" in names

    assert Enum.find(diagnostics, &(&1.file == Path.expand(app))).severity == :deny
    assert Enum.find(diagnostics, &(&1.file == vue)).severity == :warn
    assert Enum.find(diagnostics, &(&1.file == svelte)).severity == :warn

    for batch <- batches do
      assert batch["source_overrides"][Path.expand(vue <> ".script0.ts")] =~ "vueValue"
      assert batch["source_overrides"][Path.expand(svelte <> ".script0.ts")] =~ "svelteValue"
    end
  end

  defp fake_tsgolint!(dir) do
    fake_executable!(dir, "tsgolint", """
    json = ~s({"rule":"no-floating-promises","message":{"description":"floating promise"},"file_path":"typed.ts","range":{"pos":0,"end":5}})
    IO.binwrite(<<byte_size(json)::32-little, 1, json::binary>>)
    """)
  end

  defp fake_tsgolint_capture!(dir) do
    payload_path = Path.join(dir, "payload.json")

    fake_executable!(dir, "tsgolint-capture", """
    File.write!(#{inspect(payload_path)}, IO.binread(:stdio, :eof))
    """)
  end

  defp fake_tsgolint_unknown_retry!(dir) do
    payload_path = Path.join(dir, "payload.json")
    input_path = Path.join(dir, "payload-attempt.json")

    fake_executable!(dir, "tsgolint-unknown-retry", """
    payload = IO.binread(:stdio, :eof)
    File.write!(#{inspect(input_path)}, payload)

    if String.contains?(payload, "consistent-type-imports") do
      IO.puts(:stderr, "panic: unknown rule: consistent-type-imports [recovered, repanicked]")
      System.halt(2)
    end

    File.write!(#{inspect(payload_path)}, payload)
    """)
  end

  defp fake_executable!(dir, name, code) do
    script = Path.expand("#{name}.exs", dir)
    File.write!(script, ":io.setopts(:standard_io, encoding: :latin1)\n" <> code)

    case :os.type() do
      {:win32, _name} ->
        path = Path.expand("#{name}.cmd", dir)
        File.write!(path, "@echo off\r\nelixir.bat \"#{script}\"\r\n")
        path

      _unix ->
        path = Path.expand(name, dir)
        File.write!(path, "#!/bin/sh\nexec elixir \"#{script}\"\n")
        File.chmod!(path, 0o755)
        path
    end
  end
end
