defmodule Volt.PublicDirTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.{Artifact, Plan}
  @moduletag :tmp_dir

  test "explicit public root prefixes nested compiled outputs", %{tmp_dir: root} do
    public = Path.join(root, "public")
    File.mkdir_p!(public)
    File.write!(Path.join(public, "robots.txt"), "public")
    {:ok, plan} = Plan.new([%Artifact{file: "app.js", content: "script"}])
    output = Path.join(root, "dist/assets")
    static = Path.join(root, "dist")
    assert {:ok, ^static, combined} = Volt.PublicDir.prepare_output(plan, output, public, static)
    assert Enum.map(combined.artifacts, & &1.file) == ["assets/app.js", "robots.txt"]
    refute File.exists?(static)
  end

  test "can represent the lower-level parent-directory contract", %{tmp_dir: root} do
    {:ok, plan} = Plan.new([%Artifact{file: "app.js", content: "script"}])

    assert {:ok, ^root, combined} =
             Volt.PublicDir.prepare_output(plan, Path.join(root, "assets"), nil, root)

    assert [%Artifact{file: "assets/app.js"}] = combined.artifacts
  end

  test "rejects unrelated public destinations", %{tmp_dir: root} do
    {:ok, plan} = Plan.new([])

    assert {:error, {:invalid_publication_root, _, _}} =
             Volt.PublicDir.prepare_output(
               plan,
               Path.join(root, "assets"),
               nil,
               Path.join(root, "other")
             )
  end
end
