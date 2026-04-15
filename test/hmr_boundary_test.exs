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

    test "rejects code without accept" do
      refute Boundary.self_accepting?("const x = 1")
    end

    test "rejects code with only import.meta.hot but no accept" do
      refute Boundary.self_accepting?("if (import.meta.hot) { import.meta.hot.dispose() }")
    end
  end

  describe "find_boundary/2" do
    setup do
      Volt.DepGraph.clear()
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

    test "finds boundary in parent module" do
      Volt.DepGraph.update("/app/App.tsx", ["./Button"])

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
