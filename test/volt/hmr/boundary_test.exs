defmodule Volt.HMR.BoundaryTest do
  use ExUnit.Case, async: true

  alias Volt.HMR.Boundary

  describe "self_accepting?/1" do
    test "detects import.meta.hot.accept()" do
      assert Boundary.self_accepting?("""
               if (import.meta.hot) {
                 import.meta.hot.accept()
               }
             """)
    end

    test "detects import.meta.hot.accept(callback)" do
      assert Boundary.self_accepting?("import.meta.hot.accept((mod) => console.log(mod))")
    end

    test "rejects dependency accept calls" do
      refute Boundary.self_accepting?(~s|import.meta.hot.accept("./dep", () => {})|)
      refute Boundary.self_accepting?(~s|import.meta.hot.accept(["./dep"], () => {})|)
    end

    test "rejects code without accept" do
      refute Boundary.self_accepting?("const x = 1")
    end

    test "rejects code with only import.meta.hot but no accept" do
      refute Boundary.self_accepting?("if (import.meta.hot) { import.meta.hot.dispose() }")
    end

    test "rejects comments and unrelated hot.accept calls" do
      refute Boundary.self_accepting?("// import.meta.hot.accept()")
      refute Boundary.self_accepting?("foo.hot.accept()")
    end
  end

  describe "find_boundary/2" do
    setup do
      Volt.HMR.ImportGraph.clear()
      Volt.HMR.ModuleGraph.clear()
      :ok
    end

    test "returns changed file when it self-accepts" do
      source_with_hmr = """
        export const x = 1;
        if (import.meta.hot) {
          import.meta.hot.accept()
        }
      """

      read = fn _path -> source_with_hmr end

      assert {:ok, "/app/Button.tsx"} =
               Boundary.find_boundary("/app/Button.tsx", read)
    end

    test "returns :full_reload when no boundary exists" do
      read = fn _path -> "export const x = 1" end

      assert :full_reload = Boundary.find_boundary("/app/utils.ts", read)
    end

    test "finds dependency-accepting boundary in parent module through HMR module graph" do
      app = Path.expand("app/App.tsx")
      button = Path.expand("app/Button.tsx")

      Volt.HMR.ModuleGraph.update_module(
        "/assets/App.tsx",
        "/assets/App.tsx",
        app,
        ["/assets/Button.tsx"]
      )

      Volt.HMR.ModuleGraph.update_module(
        "/assets/Button.tsx",
        "/assets/Button.tsx",
        button,
        []
      )

      sources = %{
        app =>
          "import Button from './Button'\nif (import.meta.hot) { import.meta.hot.accept('./Button', () => {}) }",
        button => "export default function Button() {}"
      }

      assert {:ok, ^app} = Boundary.find_boundary(button, &Map.fetch!(sources, &1))
    end

    test "finds boundary in parent module through HMR module graph" do
      Volt.HMR.ModuleGraph.update_module(
        "/assets/App.tsx",
        "/assets/App.tsx",
        "/app/App.tsx",
        ["/assets/Button.tsx"],
        self_accepting: true
      )

      Volt.HMR.ModuleGraph.update_module(
        "/assets/Button.tsx",
        "/assets/Button.tsx",
        "/app/Button.tsx",
        []
      )

      read = fn
        "/app/App.tsx" ->
          "import Button from './Button'\nif (import.meta.hot) { import.meta.hot.accept() }"

        "/app/Button.tsx" ->
          "export default function Button() {}"
      end

      assert {:ok, "/app/App.tsx"} =
               Boundary.find_boundary("/app/Button.tsx", read)
    end

    test "prefers current source over stale graph self-accepting flag" do
      Volt.HMR.ModuleGraph.update_module(
        "/assets/App.tsx",
        "/assets/App.tsx",
        "/app/App.tsx",
        [],
        self_accepting: true
      )

      read = fn "/app/App.tsx" -> "export default function App() {}" end

      assert :full_reload = Boundary.find_boundary("/app/App.tsx", read)
    end

    test "falls back to raw import graph" do
      Volt.HMR.ImportGraph.update("/app/App.tsx", ["./Button"])

      read = fn
        "/app/App.tsx" ->
          "import Button from './Button'\nif (import.meta.hot) { import.meta.hot.accept() }"

        "/app/Button.tsx" ->
          "export default function Button() {}"
      end

      assert {:ok, "/app/App.tsx"} =
               Boundary.find_boundary("/app/Button.tsx", read)
    end

    test "returns :full_reload when file doesn't exist" do
      read = fn _path -> nil end

      assert :full_reload = Boundary.find_boundary("/app/missing.ts", read)
    end
  end
end
