defmodule Volt.JS.Transforms.GlobImportsTest do
  use ExUnit.Case, async: true

  import Volt.Test.Sigils

  @fixture_dir Path.join(System.tmp_dir!(), "volt-glob-imports-test")

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "pages"))
    File.write!(Path.join(@fixture_dir, "pages/home.ts"), "export const name = 'home'")
    File.write!(Path.join(@fixture_dir, "pages/about.ts"), "export const name = 'about'")
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "patterns/2" do
    test "extracts glob patterns without transforming source" do
      source = ~TS"const modules = import.meta.glob(['./pages/*.ts', '!./pages/about.ts'])"

      assert Volt.JS.Transforms.GlobImports.patterns(source, "app.ts") == [
               "./pages/*.ts",
               "!./pages/about.ts"
             ]
    end

    test "does not treat arbitrary .glob calls as import.meta.glob" do
      assert Volt.JS.Transforms.GlobImports.patterns("const modules = meta.glob('./pages/*.ts')") ==
               []
    end
  end

  describe "transform/2 lazy" do
    test "expands glob into lazy import map" do
      source = ~TS"const modules = import.meta.glob('./pages/*.ts')"
      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "\"./pages/about.ts\":"
      assert result =~ "\"./pages/home.ts\":"
      assert result =~ "() => import("
      refute result =~ "import.meta.glob"
    end
  end

  describe "transform/2 eager" do
    test "expands glob into eager imports" do
      source = ~TS"const modules = import.meta.glob('./pages/*.ts', { eager: true })"
      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "import * as __glob_"
      assert result =~ "\"./pages/home.ts\":"
      refute result =~ "() => import("
      refute result =~ "import.meta.glob"
    end

    test "supports array patterns with exclusions" do
      source =
        ~TS"const modules = import.meta.glob(['./pages/*.ts', '!./pages/about.ts'], { eager: true })"

      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "./pages/home.ts"
      refute result =~ "./pages/about.ts"
    end

    test "supports eager named imports" do
      source = "const modules = import.meta.glob('./pages/*.ts', { eager: true, import: 'name' })"
      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "import { name as __glob_"
      assert result =~ "\"./pages/home.ts\":"
    end

    test "supports query option" do
      source = "const modules = import.meta.glob('./pages/*.ts', { eager: true, query: '?raw' })"
      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "./pages/home.ts?raw"
    end

    test "supports object query option" do
      source =
        "const modules = import.meta.glob('./pages/*.ts', { eager: true, query: { raw: true, lang: 'ts' } })"

      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "./pages/home.ts?raw=true&lang=ts"
    end

    test "supports base option for object keys" do
      source =
        "const modules = import.meta.glob('./pages/*.ts', { eager: true, base: './pages' })"

      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ ~S("./home.ts":)
      assert result =~ ~S(from "./pages/home.ts")
    end

    test "supports TypeScript generic syntax" do
      source = ~TS"const modules = import.meta.glob<Module>('./pages/*.ts')"
      result = Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir)

      assert result =~ "./pages/home.ts"
      refute result =~ "import.meta.glob"
    end
  end

  describe "transform/2 no glob" do
    test "passes through code without glob" do
      source = ~TS"const x = 42"
      assert Volt.JS.Transforms.GlobImports.transform(source, @fixture_dir) == source
    end
  end
end
