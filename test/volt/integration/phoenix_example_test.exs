defmodule Volt.Integration.PhoenixExample do
  @moduledoc "Prepares the Phoenix example application for integration tests."

  @example_dir Path.join(File.cwd!(), "examples/vanilla")

  def example_dir, do: @example_dir
  def assets_root, do: Path.join(@example_dir, "assets")
  def outdir, do: Path.join(@example_dir, "priv/static/assets")

  def ensure_ready! do
    unless File.dir?(Path.join(@example_dir, "deps/phoenix")) do
      run!("mix", ["deps.get"])
    end

    unless File.dir?(Path.join(@example_dir, "node_modules/phoenix")) do
      run!("mix", ["npm.install"])
    end

    :ok
  end

  defp run!(command, args) do
    case System.cmd(command, args, cd: @example_dir, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, status} ->
        raise "#{command} #{Enum.join(args, " ")} failed with #{status}:\n#{output}"
    end
  end
end

defmodule Volt.Integration.PhoenixExampleTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import Plug.Test
  import Plug.Conn

  @assets_root Volt.Integration.PhoenixExample.assets_root()

  setup_all do
    Volt.Integration.PhoenixExample.ensure_ready!()
  end

  describe "dev server" do
    setup do
      Volt.Cache.clear()
      :ok
    end

    test "serves entry module with HMR preamble and rewritten imports" do
      conn = call_dev_server("/assets/js/app.ts")

      assert conn.status == 200
      assert content_type(conn) =~ "javascript"
      assert conn.resp_body =~ "createHotContext"
      assert conn.resp_body =~ "/@vendor/phoenix.js"
      assert conn.resp_body =~ "/@vendor/phoenix_html.js"
      assert conn.resp_body =~ "/@vendor/phoenix_live_view.js"
      refute conn.resp_body =~ ~s(from 'phoenix')
      refute conn.resp_body =~ ~s(from 'phoenix_html')
      refute conn.resp_body =~ ~s(from 'phoenix_live_view')
    end

    test "serves hook modules with HMR preamble" do
      conn = call_dev_server("/assets/js/hooks/clock.ts")

      assert conn.status == 200
      assert conn.resp_body =~ "createHotContext"
      assert conn.resp_body =~ "clearInterval"
    end

    test "rewrites relative imports to absolute dev paths" do
      conn = call_dev_server("/assets/js/app.ts")

      assert conn.resp_body =~ "/assets/js/hooks/clock"
      assert conn.resp_body =~ "/assets/js/hooks/env-mode"
    end

    test "serves vendor phoenix module" do
      conn = call_dev_server("/@vendor/phoenix.js")

      assert conn.status == 200
      assert content_type(conn) =~ "javascript"
      assert conn.resp_body =~ "Socket"
      assert conn.resp_body =~ "Channel"
    end

    test "serves vendor phoenix_live_view module" do
      conn = call_dev_server("/@vendor/phoenix_live_view.js")

      assert conn.status == 200
      assert content_type(conn) =~ "javascript"
      assert conn.resp_body =~ "LiveSocket"
    end

    test "serves vendor phoenix_html module" do
      conn = call_dev_server("/@vendor/phoenix_html.js")

      assert conn.status == 200
      assert content_type(conn) =~ "javascript"
    end

    test "serves JSON modules" do
      conn = call_dev_server("/assets/js/config.json")

      assert conn.status == 200
      assert conn.resp_body =~ "export default"
    end

    test "serves static assets" do
      conn = call_dev_server("/assets/images/volt.svg")

      assert conn.status == 200
      assert content_type(conn) =~ "svg"
    end
  end

  defp call_dev_server(path) do
    opts = Volt.DevServer.init(root: @assets_root, prefix: "/assets")
    conn(:get, path) |> Volt.DevServer.call(opts)
  end

  defp content_type(conn) do
    get_resp_header(conn, "content-type") |> hd()
  end
end

defmodule Volt.Integration.PhoenixExampleBuildTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @example_dir Volt.Integration.PhoenixExample.example_dir()
  @outdir Volt.Integration.PhoenixExample.outdir()

  defmodule Endpoint do
    def config(:code_reloader), do: false
    def static_path(path), do: path
  end

  setup_all do
    Volt.Integration.PhoenixExample.ensure_ready!()

    File.rm_rf!(Path.join(@outdir, "js"))
    File.rm_rf!(Path.join(@outdir, "css"))

    {output, status} =
      System.cmd("mix", ["volt.build", "--tailwind", "--hash", "--no-minify"],
        cd: @example_dir,
        stderr_to_stdout: true
      )

    %{build_output: output, build_status: status}
  end

  test "exits successfully", %{build_status: status} do
    assert status == 0
  end

  test "produces JS bundle with Phoenix deps bundled in", %{build_status: 0} do
    js = File.read!(js_path())

    assert js =~ "LiveSocket"
    assert js =~ "phoenix"
    assert js =~ "csrfToken"
    refute js =~ ~s(import "phoenix")
    refute js =~ ~s(import "phoenix_html")
  end

  test "includes glob imports in bundle", %{build_status: 0} do
    js = File.read!(js_path())

    assert js =~ "About"
    assert js =~ "Built with Volt"
    assert js =~ "Home"
  end

  test "produces valid manifest", %{build_status: 0} do
    manifest = @outdir |> Path.join("js/manifest.json") |> File.read!() |> Jason.decode!()

    assert Map.has_key?(manifest, "app.js")
    assert manifest["app.js"]["file"] =~ ~r/^app-[a-f0-9]{8}\.js$/
  end

  test "produces valid Tailwind manifest", %{build_status: 0} do
    manifest = @outdir |> Path.join("css/manifest.json") |> File.read!() |> Jason.decode!()

    assert Map.has_key?(manifest, "app.css")
    assert manifest["app.css"]["file"] =~ ~r/^app-[a-f0-9]{8}\.css$/
  end

  test "produces Tailwind CSS with utility classes from heex templates", %{build_status: 0} do
    manifest = @outdir |> Path.join("css/manifest.json") |> File.read!() |> Jason.decode!()
    css = File.read!(Path.join([@outdir, "css", manifest["app.css"]["file"]]))

    assert css =~ "rounded-2xl"
    assert css =~ "bg-amber-600"
    assert css =~ "font-semibold"
  end

  test "produces Tailwind CSS with Phoenix colocated CSS", %{build_status: 0} do
    manifest = @outdir |> Path.join("css/manifest.json") |> File.read!() |> Jason.decode!()
    css = File.read!(Path.join([@outdir, "css", manifest["app.css"]["file"]]))

    assert css =~ ".colocated-card"
    assert css =~ "oklch(98.7% .022 95.277)"
  end

  test "generates sourcemap", %{build_status: 0} do
    manifest = @outdir |> Path.join("js/manifest.json") |> File.read!() |> Jason.decode!()
    map_path = manifest["app.js"]["file"] <> ".map"
    map = [@outdir, "js", map_path] |> Path.join() |> File.read!() |> Jason.decode!()

    assert map["version"] == 3
  end

  test "Volt.static_path resolves hashed production assets", %{build_status: 0} do
    assert Volt.static_path(
             Volt.Integration.PhoenixExampleBuildTest.Endpoint,
             "/assets/js/app.js",
             outdir: @outdir,
             prefix: "/assets"
           ) =~ ~r|^/assets/js/app-[a-f0-9]{8}\.js$|

    assert Volt.static_path(
             Volt.Integration.PhoenixExampleBuildTest.Endpoint,
             "/assets/css/app.css",
             outdir: @outdir,
             prefix: "/assets"
           ) =~ ~r|^/assets/css/app-[a-f0-9]{8}\.css$|
  end

  defp js_path do
    manifest = @outdir |> Path.join("js/manifest.json") |> File.read!() |> Jason.decode!()
    Path.join([@outdir, "js", manifest["app.js"]["file"]])
  end
end
