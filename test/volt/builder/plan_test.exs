defmodule Volt.Builder.PlanTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.{Artifact, Plan, Writer}

  @moduletag :tmp_dir

  test "validates manifest keys independently of output filenames" do
    {:ok, plan} =
      Plan.new([
        %Artifact{file: "js/main-hash.js", content: ""},
        %Artifact{file: "js/shared-hash.js", content: ""}
      ])

    manifest = %{
      "main" => %Volt.Builder.ManifestEntry{file: "js/main-hash.js", imports: ["shared"]},
      "shared" => %Volt.Builder.ManifestEntry{file: "js/shared-hash.js", imports: ["main"]}
    }

    assert :ok = Plan.validate_manifest(plan, manifest)

    broken =
      Map.put(manifest, "main", %Volt.Builder.ManifestEntry{
        file: "js/main-hash.js",
        imports: ["js/shared-hash.js"],
        dynamicImports: ["lazy"],
        css: ["missing.css"],
        assets: ["missing.svg"]
      })

    assert {:error, {:invalid_manifest, errors}} = Plan.validate_manifest(plan, broken)
    assert {:missing_manifest_entry, "main", "js/shared-hash.js"} in errors
    assert {:missing_manifest_entry, "main", "lazy"} in errors
    assert {:missing_artifact, "main", "missing.css"} in errors
    assert {:missing_artifact, "main", "missing.svg"} in errors
    assert length(errors) == 4
  end

  test "deduplicates identical outputs and orders the plan" do
    a = %Artifact{file: "a.js", content: "a"}
    b = %Artifact{file: "nested/b.js", content: "b"}
    assert {:ok, %Plan{artifacts: [^a, ^b]}} = Plan.new([b, a, b])
  end

  test "rejects conflicting output before replacing a previous file", %{tmp_dir: root} do
    previous = Path.join(root, "app.js")
    File.write!(previous, "previous")

    result =
      with {:ok, plan} <-
             Plan.new([
               %Artifact{file: "app.js", content: "first"},
               %Artifact{file: "app.js", content: "second"}
             ]) do
        Writer.write_plan(root, plan)
      end

    assert result == {:error, {:output_collision, "app.js"}}
    assert File.read!(previous) == "previous"
  end

  test "rejects unsafe and ambiguous relative paths" do
    for file <- [
          "",
          ".",
          "..",
          "../app.js",
          "/app.js",
          "nested/../app.js",
          "nested//app.js",
          "nested/./app.js",
          "C:\\app.js",
          "nested\\app.js",
          "bad\0.js"
        ] do
      assert {:error, {:invalid_output_path, ^file}} =
               Plan.new([%Artifact{file: file, content: ""}])
    end
  end

  test "writes all validated artifacts including nested outputs", %{tmp_dir: root} do
    assert {:ok, plan} =
             Plan.new([
               %Artifact{file: "js/app.js", content: "run();"},
               %Artifact{file: "css/app.css", content: "body{}"}
             ])

    assert :ok = Writer.write_plan(root, plan)
    assert File.read!(Path.join(root, "js/app.js")) == "run();"
    assert File.read!(Path.join(root, "css/app.css")) == "body{}"
  end
end
