defmodule Volt.JS.GlobImportTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/glob", __DIR__)

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "pages"))
    File.write!(Path.join(@fixture_dir, "pages/home.ts"), "export const name = 'home'")
    File.write!(Path.join(@fixture_dir, "pages/about.ts"), "export const name = 'about'")
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "transform/2 lazy" do
    test "expands glob into lazy import map" do
      source = "const modules = import.meta.glob('./pages/*.ts')"
      result = Volt.JS.GlobImport.transform(source, @fixture_dir)

      assert result =~ "\"./pages/about.ts\":"
      assert result =~ "\"./pages/home.ts\":"
      assert result =~ "() => import("
      refute result =~ "import.meta.glob"
    end
  end

  describe "transform/2 eager" do
    test "expands glob into eager imports" do
      source = "const modules = import.meta.glob('./pages/*.ts', { eager: true })"
      result = Volt.JS.GlobImport.transform(source, @fixture_dir)

      assert result =~ "import * as __glob_"
      assert result =~ "\"./pages/home.ts\":"
      refute result =~ "() => import("
      refute result =~ "import.meta.glob"
    end
  end

  describe "transform/2 no glob" do
    test "passes through code without glob" do
      source = "const x = 42"
      assert Volt.JS.GlobImport.transform(source, @fixture_dir) == source
    end
  end
end
