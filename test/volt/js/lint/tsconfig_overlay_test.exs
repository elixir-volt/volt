defmodule Volt.JS.Lint.TSConfigOverlayTest do
  use ExUnit.Case, async: true

  alias Volt.JS.Lint.TSConfigOverlay

  @moduletag :tmp_dir

  defp write!(root, path, content) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  test "adds virtual modules to the project of the nearest tsconfig", %{tmp_dir: root} do
    original = """
    {
      // comments and trailing commas are allowed in a tsconfig
      "compilerOptions": { "paths": { "@/*": ["./assets/js/*"] }, },
      "include": ["assets/js/**/*.ts"],
    }
    """

    tsconfig = write!(root, "tsconfig.json", original)
    first = Path.join(root, "lib/app_web/Tally.vue.script0.ts")
    second = Path.join(root, "assets/js/Card.vue.script0.ts")

    overrides = TSConfigOverlay.overrides([first, second])

    # The original is carried unchanged beside the tsconfig that replaces it.
    assert overrides[Path.join(root, "tsconfig.volt-base.json")] == original

    assert Jason.decode!(overrides[tsconfig]) == %{
             "extends" => "./tsconfig.volt-base.json",
             "files" => [second, first]
           }
  end

  test "keeps the files the original names, which `files` would replace", %{tmp_dir: root} do
    tsconfig = write!(root, "tsconfig.json", ~s({ files: ["src/main.ts", "./env.d.ts"] }))
    virtual = Path.join(root, "src/App.vue.script0.ts")

    assert %{"files" => ["src/main.ts", "./env.d.ts", ^virtual]} =
             TSConfigOverlay.overrides([virtual])[tsconfig] |> Jason.decode!()
  end

  test "spells out the default include a tsconfig without one relies on", %{tmp_dir: root} do
    tsconfig = write!(root, "tsconfig.json", ~s({ "compilerOptions": { "strict": true } }))
    virtual = Path.join(root, "App.vue.script0.ts")

    assert %{"include" => ["**/*"], "files" => [^virtual]} =
             TSConfigOverlay.overrides([virtual])[tsconfig] |> Jason.decode!()
  end

  test "uses the nearest tsconfig for each virtual module", %{tmp_dir: root} do
    outer = write!(root, "tsconfig.json", ~s({ "include": ["**/*"] }))
    inner = write!(root, "assets/tsconfig.json", ~s({ "include": ["**/*"] }))
    in_lib = Path.join(root, "lib/Page.vue.script0.ts")
    in_assets = Path.join(root, "assets/js/App.vue.script0.ts")

    overrides = TSConfigOverlay.overrides([in_lib, in_assets])

    assert %{"files" => [^in_lib]} = Jason.decode!(overrides[outer])
    assert %{"files" => [^in_assets]} = Jason.decode!(overrides[inner])
  end

  test "leaves virtual modules alone without a readable tsconfig above them", %{tmp_dir: root} do
    write!(root, "broken/tsconfig.json", "not a config")

    assert TSConfigOverlay.overrides([Path.join(root, "broken/App.vue.script0.ts")]) == %{}
  end
end
