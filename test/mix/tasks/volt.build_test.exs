defmodule Mix.Tasks.Volt.BuildTest do
  use ExUnit.Case, async: false

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    Mix.Task.reenable("volt.build")

    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-build-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp_dir, "src"))

    on_exit(fn ->
      Mix.shell(previous_shell)
      Mix.Task.reenable("volt.build")
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "--no-tree-shaking is accepted", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "src/app.js")
    outdir = Path.join(tmp_dir, "dist")

    File.write!(Path.join(tmp_dir, "src/lib.js"), """
    export function used() { return 'used' }
    export function unused() { return 'unused' }
    """)

    File.write!(entry, """
    import { used } from './lib.js'
    console.log(used())
    """)

    Mix.Tasks.Volt.Build.run([
      "--entry",
      entry,
      "--outdir",
      outdir,
      "--no-hash",
      "--no-minify",
      "--no-tailwind",
      "--format",
      "iife",
      "--sourcemap",
      "false",
      "--no-tree-shaking"
    ])

    js_path = Path.join([outdir, "js", "app.js"])
    assert File.read!(js_path) =~ "used"
  end

  test "--asset-url-prefix sets production asset URLs", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "src/app.js")
    outdir = Path.join(tmp_dir, "dist")

    File.write!(Path.join(tmp_dir, "src/logo.svg"), "<svg></svg>")

    File.write!(entry, """
    import logo from './logo.svg?url'
    console.log(logo)
    """)

    Mix.Tasks.Volt.Build.run([
      "--entry",
      entry,
      "--outdir",
      outdir,
      "--asset-url-prefix",
      "/cdn/assets",
      "--no-hash",
      "--no-minify",
      "--no-tailwind",
      "--format",
      "iife",
      "--sourcemap",
      "false"
    ])

    js_path = Path.join([outdir, "js", "app.js"])
    assert File.read!(js_path) =~ ~r(/cdn/assets/logo-[a-f0-9]{8}\.svg)
  end

  test "--sourcemap false disables production sourcemaps", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "src/app.js")
    outdir = Path.join(tmp_dir, "dist")

    File.write!(entry, "console.log('app')")

    Mix.Tasks.Volt.Build.run([
      "--entry",
      entry,
      "--outdir",
      outdir,
      "--no-hash",
      "--no-minify",
      "--no-tailwind",
      "--format",
      "iife",
      "--sourcemap",
      "false"
    ])

    js_path = Path.join([outdir, "js", "app.js"])
    assert File.regular?(js_path)
    refute File.exists?(js_path <> ".map")
  end

  test "Tailwind build uses configured hash setting", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "src/app.js")
    css_path = Path.join(tmp_dir, "src/app.css")
    outdir = Path.join(tmp_dir, "dist")
    previous_env = Application.get_all_env(:volt)

    Application.put_env(:volt, :entry, entry)
    Application.put_env(:volt, :outdir, outdir)
    Application.put_env(:volt, :hash, false)
    Application.put_env(:volt, :minify, false)
    Application.put_env(:volt, :sourcemap, false)
    Application.put_env(:volt, :format, :iife)

    Application.put_env(:volt, :tailwind,
      css: css_path,
      sources: [%{base: Path.join(tmp_dir, "src"), pattern: "**/*"}]
    )

    on_exit(fn ->
      for {key, _value} <- Application.get_all_env(:volt) do
        Application.delete_env(:volt, key)
      end

      for {key, value} <- previous_env do
        Application.put_env(:volt, key, value)
      end
    end)

    File.write!(entry, "console.log('app')")
    File.write!(css_path, "@import \"tailwindcss\" source(none);\n")

    Mix.Tasks.Volt.Build.run(["--tailwind"])

    css_manifest = outdir |> Path.join("css/manifest.json") |> File.read!() |> Jason.decode!()

    assert File.regular?(Path.join([outdir, "css", "app.css"]))
    assert File.regular?(Path.join([outdir, "js", "app.js"]))
    assert css_manifest["app.css"]["file"] == "app.css"

    refute outdir
           |> Path.join("css")
           |> File.ls!()
           |> Enum.any?(&String.match?(&1, ~r/^app-[a-f0-9]{8}\.css$/))
  end
end
