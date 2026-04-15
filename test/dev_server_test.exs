defmodule Volt.DevServerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  @fixture_dir Path.expand("fixtures", __DIR__)

  setup do
    File.mkdir_p!(Path.join(@fixture_dir, "src"))
    File.write!(Path.join(@fixture_dir, "src/app.ts"), "const x: number = 42")
    File.write!(Path.join(@fixture_dir, "src/style.css"), ".foo { color: red }")

    File.write!(Path.join(@fixture_dir, "src/App.vue"), """
    <template><div>{{ msg }}</div></template>
    <script setup>const msg = 'hi'</script>
    """)

    Volt.Cache.clear()

    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  defp call_dev_server(path, opts \\ []) do
    init_opts =
      Keyword.merge(
        [root: Path.join(@fixture_dir, "src"), prefix: "/assets"],
        opts
      )

    opts = Volt.DevServer.init(init_opts)
    conn(:get, path) |> Volt.DevServer.call(opts)
  end

  describe "TypeScript files" do
    test "serves compiled TypeScript" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "const x = 42"
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "includes inline sourcemap" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.resp_body =~ "sourceMappingURL=data:application/json;base64,"
    end
  end

  describe "Vue SFCs" do
    test "serves compiled Vue SFC" do
      conn = call_dev_server("/assets/App.vue")
      assert conn.status == 200
      assert conn.resp_body =~ "msg"
    end
  end

  describe "CSS files" do
    test "serves CSS with correct content type" do
      conn = call_dev_server("/assets/style.css")
      assert conn.status == 200
      assert conn.resp_body =~ "color"
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/css"
    end
  end

  describe "caching" do
    test "serves from cache on second request" do
      call_dev_server("/assets/app.ts")
      conn = call_dev_server("/assets/app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "const x = 42"
    end
  end

  describe "non-matching paths" do
    test "passes through non-matching prefix" do
      conn = call_dev_server("/other/app.ts")
      refute conn.halted
    end

    test "serves static assets with correct MIME type" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "image/png"
    end

    test "passes through unknown extensions" do
      File.write!(Path.join(@fixture_dir, "src/data.xyz"), "binary")
      conn = call_dev_server("/assets/data.xyz")
      refute conn.halted
    end

    test "passes through missing files" do
      conn = call_dev_server("/assets/missing.ts")
      refute conn.halted
    end
  end

  describe "error handling" do
    test "returns 500 with error overlay for invalid source" do
      File.write!(Path.join(@fixture_dir, "src/bad.ts"), "const = ;")
      conn = call_dev_server("/assets/bad.ts")
      assert conn.status == 500
      assert conn.resp_body =~ "[Volt] Compilation error"
    end
  end

  describe "import rewriting" do
    test "rewrites relative imports to absolute paths" do
      File.write!(Path.join(@fixture_dir, "src/utils.ts"), "export const y = 1")

      File.write!(Path.join(@fixture_dir, "src/entry.ts"), """
      import { y } from './utils'
      console.log(y)
      """)

      conn = call_dev_server("/assets/entry.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/assets/utils.ts"
      refute conn.resp_body =~ "'./utils'"
    end

    test "rewrites bare imports to vendor URLs" do
      File.write!(Path.join(@fixture_dir, "src/vue_app.ts"), """
      import { ref } from 'vue'
      ref(0)
      """)

      conn = call_dev_server("/assets/vue_app.ts")
      assert conn.status == 200
      assert conn.resp_body =~ "/@vendor/vue.js"
      refute conn.resp_body =~ "'vue'"
    end
  end

  describe "HMR preamble" do
    test "injects import.meta.hot into JS modules" do
      conn = call_dev_server("/assets/app.ts")
      assert conn.resp_body =~ "import.meta.hot"
      assert conn.resp_body =~ "createHotContext"
    end

    test "does not inject HMR preamble into CSS" do
      conn = call_dev_server("/assets/style.css")
      refute conn.resp_body =~ "import.meta.hot"
    end
  end
end
