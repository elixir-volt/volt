defmodule Volt.HTMLEntryTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/html_entry", __DIR__)

  setup do
    File.mkdir_p!(@fixture_dir)
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "extract/1" do
    test "extracts script src" do
      File.write!(Path.join(@fixture_dir, "index.html"), """
      <html>
        <body>
          <script type="module" src="js/app.ts"></script>
        </body>
      </html>
      """)

      {:ok, entries} = Volt.HTMLEntry.extract(Path.join(@fixture_dir, "index.html"))
      assert length(entries.scripts) == 1
      assert hd(entries.scripts) =~ "js/app.ts"
    end

    test "extracts stylesheet href" do
      File.write!(Path.join(@fixture_dir, "index.html"), """
      <html>
        <head>
          <link rel="stylesheet" href="css/app.css">
        </head>
      </html>
      """)

      {:ok, entries} = Volt.HTMLEntry.extract(Path.join(@fixture_dir, "index.html"))
      assert length(entries.styles) == 1
      assert hd(entries.styles) =~ "css/app.css"
    end

    test "extracts multiple entries" do
      File.write!(Path.join(@fixture_dir, "index.html"), """
      <html>
        <head>
          <link rel="stylesheet" href="css/app.css">
          <link rel="stylesheet" href="css/vendor.css">
        </head>
        <body>
          <script type="module" src="js/app.ts"></script>
          <script type="module" src="js/admin.ts"></script>
        </body>
      </html>
      """)

      {:ok, entries} = Volt.HTMLEntry.extract(Path.join(@fixture_dir, "index.html"))
      assert length(entries.scripts) == 2
      assert length(entries.styles) == 2
    end
  end

  describe "html?/1" do
    test "recognizes HTML files" do
      assert Volt.HTMLEntry.html?("index.html")
      assert Volt.HTMLEntry.html?("page.htm")
    end

    test "rejects non-HTML" do
      refute Volt.HTMLEntry.html?("app.ts")
      refute Volt.HTMLEntry.html?("style.css")
    end
  end
end
