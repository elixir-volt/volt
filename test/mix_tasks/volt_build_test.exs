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
end
