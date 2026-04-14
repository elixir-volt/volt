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

    test "loads local stylesheets via @import" do
      File.write!(Path.join(@fixture_dir, "extra.css"), ".banner { color: rebeccapurple; }")

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"./extra.css\";\n@import \"tailwindcss\";",
          css_base: @fixture_dir
        )

      assert css =~ ".banner"
      assert css =~ "rebeccapurple"
    end

    test "loads local references via @reference" do
      File.write!(Path.join(@fixture_dir, "reference.css"), """
      @import "tailwindcss";
      @theme {
        --color-brand: #123456;
      }
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@reference \"./reference.css\";\n.btn { @apply text-brand; }",
          css_base: @fixture_dir
        )

      assert css =~ ".btn"
      assert css =~ "var(--color-brand, #123456)"
    end

    test "loads local plugins via @plugin" do
      File.write!(Path.join(@fixture_dir, "plugin-utils.js"), """
      module.exports = {
        '.content-auto': {
          contentVisibility: 'auto'
        }
      }
      """)

      File.write!(Path.join(@fixture_dir, "plugin.js"), """
      const plugin = require('tailwindcss/plugin')
      const utilities = require('./plugin-utils')

      module.exports = plugin(function ({ addUtilities }) {
        addUtilities(utilities)
      })
      """)

      File.write!(Path.join(@fixture_dir, "plugin.html"), ~S(<div class="content-auto"></div>))

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@plugin \"./plugin.js\";",
          css_base: @fixture_dir
        )

      assert css =~ ".content-auto"
      assert css =~ "content-visibility: auto"
    end

    test "loads local configs via @config" do
      File.write!(Path.join(@fixture_dir, "brand.html"), ~S(<div class="text-brand"></div>))

      File.write!(Path.join(@fixture_dir, "tailwind.config.js"), """
      module.exports = {
        theme: {
          extend: {
            colors: {
              brand: '#123456'
            }
          }
        }
      }
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@config \"./tailwind.config.js\";",
          css_base: @fixture_dir
        )

      assert css =~ ".text-brand"
      assert css =~ "#123456"
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

  describe "typography plugin" do
    test "generates prose styles from @plugin directive" do
      File.write!(Path.join(@fixture_dir, "article.html"), """
      <article class="prose prose-lg dark:prose-invert">
        <h1>Hello World</h1>
      </article>
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@plugin \"@tailwindcss/typography\";"
        )

      assert css =~ ".prose"
      assert css =~ "--tw-prose-body"
      assert css =~ "max-width: 65ch"
    end

    test "generates prose size variants" do
      File.write!(Path.join(@fixture_dir, "article.html"), """
      <article class="prose prose-sm prose-lg prose-xl prose-2xl"></article>
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@plugin \"@tailwindcss/typography\";"
        )

      assert css =~ ".prose-sm"
      assert css =~ ".prose-lg"
      assert css =~ ".prose-xl"
      assert css =~ ".prose-2xl"
    end

    test "generates prose color themes" do
      File.write!(Path.join(@fixture_dir, "article.html"), """
      <article class="prose prose-slate prose-invert"></article>
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@plugin \"@tailwindcss/typography\";"
        )

      assert css =~ ".prose-slate"
      assert css =~ ".prose-invert"
    end

    test "generates prose element variant classes" do
      File.write!(Path.join(@fixture_dir, "article.html"), """
      <article class="prose prose-headings:underline prose-a:text-blue-600"></article>
      """)

      {:ok, css} =
        Volt.Tailwind.build(
          sources: [%{base: @fixture_dir, pattern: "**/*.html"}],
          css: "@import \"tailwindcss\";\n@plugin \"@tailwindcss/typography\";"
        )

      assert css =~ "prose-headings"
      assert css =~ "prose-a"
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
