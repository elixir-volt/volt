defmodule Volt.JS.Lint.ConfigTest do
  use ExUnit.Case, async: true

  alias Volt.JS.Lint.Config

  test "merges all matching overrides in order and normalizes environment/global names" do
    config =
      Config.new(
        [
          rules: %{"correctness" => :deny, "unicorn/no-null" => :deny},
          env: [:browser],
          globals: %{shared: :readonly, retained: :readonly},
          overrides: [
            %{
              files: ["scripts/**/*.{js,ts}", "build.js"],
              env: %{browser: false, node: true},
              globals: %{"shared" => :writable},
              rules: %{"unicorn/no-null" => :allow}
            },
            [
              files: ["scripts/release.*"],
              env: [:mocha],
              globals: %{shared: :off},
              rules: %{"unicorn/no-null" => :warn}
            ]
          ]
        ],
        "assets"
      )

    options = Config.options(config, "assets/scripts/release.ts")
    assert options[:rules] == %{"correctness" => :deny, "unicorn/no-null" => :warn}
    assert options[:env] == %{"browser" => false, "node" => true, "mocha" => true}
    assert options[:globals] == %{"shared" => :off, "retained" => :readonly}
    assert options[:plugins] == [:typescript]
    assert Config.options(config, "assets/build.js")[:rules]["unicorn/no-null"] == :allow
    assert Config.options(config, "assets/app.js")[:rules]["unicorn/no-null"] == :deny
  end

  test "uses the lint root, handles absolute paths, and never matches outside the root" do
    config =
      Config.new(
        [
          root: ".",
          overrides: [%{files: ["./assets/**/*.js"], rules: %{"no-debugger" => :allow}}]
        ],
        "other"
      )

    relative = Config.options(config, "assets/nested/file.js")
    assert relative[:rules] == %{"no-debugger" => :allow}
    assert relative == Config.options(config, Path.expand("assets/nested/file.js"))
    assert Config.options(config, "elsewhere/file.js")[:rules] == %{}

    scoped =
      Config.new(
        [overrides: [%{files: ["**/*.js"], rules: %{"no-debugger" => :allow}}]],
        "assets"
      )

    assert Config.options(scoped, "assets-other/file.js")[:rules] == %{}
    assert Config.options(scoped, "assets/../file.js")[:rules] == %{}
  end

  test "matches already-discovered hidden files without expanding the filesystem" do
    config =
      Config.new([overrides: [%{files: ["**/*.js"], env: [:node]}]], "hidden/.worktree/assets")

    assert Config.options(config, "hidden/.worktree/assets/.generated/build.js")[:env] == %{
             "node" => true
           }
  end

  test "requires scoped globs and rejects unsupported override settings" do
    for files <- [[], "*.js", [123], ["../*.js"], [Path.expand("*.js")]] do
      assert_raise ArgumentError, fn -> Config.new([overrides: [%{files: files}]], "assets") end
    end

    assert_raise ArgumentError, ~r/unsupported lint override keys/, fn ->
      Config.new([overrides: [%{files: ["*.js"], plugins: [:node]}]], "assets")
    end

    assert_raise GlobEx.CompileError, fn ->
      Config.new([overrides: [%{files: ["{broken"]}]], "assets")
    end
  end
end
