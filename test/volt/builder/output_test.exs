defmodule Volt.Builder.OutputTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "successful preparation returns output without creating its directory", %{tmp_dir: root} do
    outdir = Path.join(root, "unpublished")

    context = %Volt.Builder.BuildContext{
      outdir: outdir,
      hash: false,
      ctx: %Volt.Builder.OutputContext{},
      bundle_opts: [format: :esm, minify: false, sourcemap: false]
    }

    assert {:ok, result, plan} =
             Volt.Builder.Output.prepare_single(
               Path.join(root, "app.js"),
               "app",
               %Volt.Builder.Compiled{
                 scripts: [{"app.js", "console.log('prepared');"}],
                 styles: ["body { color: red }"]
               },
               context
             )

    assert result.js.path == Path.join(outdir, "app.js")
    assert Enum.map(plan.artifacts, & &1.file) == ["app.css", "app.js"]
    refute File.exists?(outdir)
  end

  test "late CSS failure leaves the existing script untouched", %{tmp_dir: root} do
    output = Path.join(root, "app.js")
    File.write!(output, "previous generation")

    context = %Volt.Builder.BuildContext{
      outdir: root,
      hash: false,
      ctx: %Volt.Builder.OutputContext{},
      bundle_opts: [format: :esm, minify: false, sourcemap: false]
    }

    assert {:error, {:css_compile_failed, _}} =
             Volt.Builder.Output.build_single(
               Path.join(root, "app.js"),
               "app",
               %Volt.Builder.Compiled{
                 scripts: [{"app.js", "console.log('next generation');"}],
                 styles: ["a { color: } }"]
               },
               context
             )

    assert File.read!(output) == "previous generation"
    assert File.ls!(root) == ["app.js"]
  end
end
