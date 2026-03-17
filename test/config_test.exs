defmodule Volt.ConfigTest do
  use ExUnit.Case, async: true

  describe "build/1" do
    test "returns defaults when no app env set" do
      config = Volt.Config.build()
      assert config.entry == "assets/js/app.ts"
      assert config.target == "es2020"
      assert config.minify == true
      assert config.external == []
      assert config.aliases == %{}
      assert config.plugins == []
      assert config.code_splitting == true
    end

    test "overrides take precedence" do
      config = Volt.Config.build(target: "es2022", minify: false)
      assert config.target == "es2022"
      assert config.minify == false
    end

    test "entry can be a list" do
      config = Volt.Config.build(entry: ["app.ts", "admin.ts"])
      assert config.entry == ["app.ts", "admin.ts"]
    end
  end

  describe "server/1" do
    test "returns defaults" do
      config = Volt.Config.server()
      assert config.prefix == "/assets"
      assert config.watch_dirs == []
    end

    test "overrides take precedence" do
      config = Volt.Config.server(prefix: "/static")
      assert config.prefix == "/static"
    end
  end
end
