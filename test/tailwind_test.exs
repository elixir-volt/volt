defmodule Volt.TailwindTest do
  use ExUnit.Case

  @fixture_dir Path.expand("fixtures/tailwind_test", __DIR__)

  setup do
    File.mkdir_p!(@fixture_dir)

    File.write!(Path.join(@fixture_dir, "page.html"), """
    <div class="flex items-center bg-blue-500">
      <span class="text-lg font-bold text-white">Title</span>
      <button class="px-4 py-2 rounded hover:bg-blue-600">Click</button>
    </div>
    """)

    File.write!(Path.join(@fixture_dir, "page.heex"), """
    <div class="mt-8 space-y-4">
      <p class="text-gray-600 dark:text-gray-300">Hello</p>
    </div>
    """)

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "build/1" do
    test "generates CSS from source files" do
      {:ok, css} =
        Volt.Tailwind.build(sources: [%{base: @fixture_dir, pattern: "**/*.{html,heex}"}])

      assert css =~ "tailwindcss"
      assert css =~ "flex"
      assert css =~ "items-center"
      assert css =~ "bg-blue-500"
      assert css =~ "font-bold"
      assert css =~ "mt-8"
      assert css =~ "text-gray-600"
    end

    test "generates CSS with custom input" do
      custom_css = """
      @layer theme, base, components, utilities;
      @theme {
        --color-brand: oklch(70% 0.213 47.604);
      }
      @tailwind utilities;
      """

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: custom_css
        )

      assert css =~ "flex"
    end

    test "minifies output" do
      {:ok, normal} =
        Volt.Tailwind.build(sources: [%{base: @fixture_dir, pattern: "**/*.html"}])

      {:ok, minified} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          minify: true
        )

      assert byte_size(minified) < byte_size(normal)
    end
  end

  describe "rebuild/2" do
    test "returns :unchanged when no new candidates" do
      {:ok, _css} =
        Volt.Tailwind.build(sources: [%{base: @fixture_dir, pattern: "**/*.html"}])

      assert :unchanged =
               Volt.Tailwind.rebuild([
                 %{content: ~s(class="flex items-center"), extension: "html"}
               ])
    end

    test "returns new CSS when new candidates found" do
      {:ok, _css} =
        Volt.Tailwind.build(sources: [%{base: @fixture_dir, pattern: "**/*.html"}])

      {:ok, css} =
        Volt.Tailwind.rebuild([
          %{content: ~s(class="grid grid-cols-3 gap-8"), extension: "html"}
        ])

      assert css =~ "grid"
      assert css =~ "gap-8"
    end
  end
end
