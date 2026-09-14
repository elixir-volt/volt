defmodule Mix.Tasks.Volt.BuildTest do
  use ExUnit.Case, async: false

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    Mix.Task.reenable("volt.build")

    tmp_dir =
      Path.expand("volt-build-test-#{System.unique_integer([:positive])}", System.tmp_dir!())

    File.mkdir_p!(Path.join(tmp_dir, "src"))

    on_exit(fn ->
      Mix.shell(previous_shell)
      Mix.Task.reenable("volt.build")
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "explicit Tailwind enablement works without configured roots", %{tmp_dir: root} do
    original = Application.get_env(:volt, :tailwind)
    Application.put_env(:volt, :tailwind, [])

    on_exit(fn ->
      if is_nil(original),
        do: Application.delete_env(:volt, :tailwind),
        else: Application.put_env(:volt, :tailwind, original)
    end)

    entry = Path.join(root, "src/app.js")
    File.write!(entry, "console.log('ready')")
    css = Path.join(root, "src/custom.css")
    File.write!(css, "@import 'tailwindcss' source(none); .custom { color: red }")

    for {name, flags, expected} <- [
          {"default", ["--tailwind"], "app.css"},
          {"custom", ["--tailwind-css", css], "custom.css"},
          {"disabled", ["--tailwind-css", css, "--no-tailwind"], nil}
        ] do
      outdir = Path.join(root, name)

      try do
        Mix.Tasks.Volt.Build.run(
          ["--entry", entry, "--outdir", outdir, "--no-hash", "--no-minify"] ++ flags
        )
      catch
        :exit, reason ->
          receive do
            {:mix_shell, :error, [message]} -> flunk("#{name}: #{message}")
          after
            0 -> exit(reason)
          end
      end

      styles = Path.wildcard(Path.join(outdir, "css/*.css"))
      assert Enum.map(styles, &Path.basename/1) == List.wrap(expected)
    end
  end

  test "nested flat assets preserve CDN URLs and sourcemaps", %{tmp_dir: root} do
    entry = Path.join(root, "src/app.js")
    File.write!(Path.join(root, "src/logo.svg"), "<svg/>")
    File.write!(Path.join(root, "src/style.css"), ".logo { background: url('./logo.svg') }")

    File.write!(
      entry,
      "import logo from './logo.svg?url'; import './style.css'; console.log(logo)"
    )

    outdir = Path.join(root, "dist")

    Mix.Tasks.Volt.Build.run([
      "--entry",
      entry,
      "--outdir",
      outdir,
      "--assets-dir",
      "assets",
      "--output-layout",
      "flat",
      "--no-hash",
      "--no-minify",
      "--no-tailwind",
      "--asset-url-prefix",
      "https://cdn.example/site",
      "--sourcemap",
      "true"
    ])

    manifest = outdir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()
    js = File.read!(Path.join(outdir, manifest["app.js"]["file"]))
    css = File.read!(Path.join(outdir, manifest["app.css"]["file"]))
    assert [image] = Path.wildcard(Path.join(outdir, "assets/logo-*.svg"))
    url = "https://cdn.example/site/assets/" <> Path.basename(image)
    assert js =~ url
    assert css =~ url
    assert js =~ "sourceMappingURL=app.js.map"
    assert File.regular?(Path.join(outdir, "assets/app.js.map"))
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
    assert File.read!(js_path) =~ ~r(/cdn/assets/js/logo-[a-f0-9]{8}\.svg)
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

    manifest = outdir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    assert manifest["app.css"]["file"] == "css/app.css"
    assert manifest["app.js"]["file"] == "js/app.js"

    refute outdir
           |> Path.join("css")
           |> File.ls!()
           |> Enum.any?(&String.match?(&1, ~r/^app-[a-f0-9]{8}\.css$/))
  end
end
