defmodule Volt.DevServer.RequestsTest do
  use Volt.TestSupport.DevServerCase

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

    test "serves asset imports as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?import")
      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/png;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves raw asset query as a JavaScript string module" do
      File.write!(Path.join(@fixture_dir, "src/data.txt"), "hello\nworld")
      conn = call_dev_server("/assets/data.txt?raw")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "hello\\nworld";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves URL asset query as a JavaScript URL module" do
      File.write!(Path.join(@fixture_dir, "src/image.png"), "binary")
      conn = call_dev_server("/assets/image.png?url")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves asset script fetches as JavaScript modules" do
      File.write!(Path.join(@fixture_dir, "src/icon.svg"), "<svg></svg>")

      opts = Volt.DevServer.init(root: Path.join(@fixture_dir, "src"), prefix: "/assets")

      conn =
        conn(:get, "/assets/icon.svg")
        |> put_req_header("sec-fetch-dest", "script")
        |> Volt.DevServer.call(opts)

      assert conn.status == 200
      assert conn.resp_body =~ ~s(export default "data:image/svg+xml;base64,)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
    end

    test "serves large asset imports with their dev URL" do
      File.mkdir_p!(Path.join(@fixture_dir, "src/images"))
      File.write!(Path.join(@fixture_dir, "src/images/image.png"), String.duplicate("x", 4097))
      conn = call_dev_server("/assets/images/image.png?import")
      assert conn.status == 200
      assert conn.resp_body == ~s(export default "/assets/images/image.png";\n)
      assert get_resp_header(conn, "content-type") |> hd() =~ "javascript"
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
      assert conn.resp_body =~ "renderErrorOverlay"
      assert conn.resp_body =~ "Compilation error"
    end
  end
end
