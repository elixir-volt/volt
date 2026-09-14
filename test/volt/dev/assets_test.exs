defmodule Volt.Dev.AssetsTest do
  use ExUnit.Case, async: false

  @tag :tmp_dir
  test "serves only resolved stylesheet assets in the owning session", %{tmp_dir: root} do
    assets = Path.join(root, "assets")
    package = Path.join(root, "node_modules/font")
    File.mkdir_p!(assets)
    File.mkdir_p!(package)
    font = Path.join(package, "font.woff2")
    File.write!(font, "font-content")

    File.write!(
      Path.join(assets, "style.css"),
      "@font-face { src: url('../node_modules/font/font.woff2?v=1#font'); }"
    )

    first = Volt.DevServer.init(root: assets, session: make_ref(), watch: true)
    second = Volt.DevServer.init(root: assets, session: make_ref(), watch: true)

    on_exit(fn ->
      Volt.Dev.stop(first.session)
      Volt.Dev.stop(second.session)
    end)

    css = Plug.Test.conn(:get, "/assets/style.css") |> Volt.DevServer.call(first)
    assert css.status == 200
    assert css.resp_body =~ "/@volt/assets/"
    assert css.resp_body =~ "?v=1#font"
    tables = Volt.Dev.tables(first.session)
    url = Volt.Dev.Assets.register(font, tables)
    served = Plug.Test.conn(:get, url) |> Volt.DevServer.call(first)
    assert served.status == 200
    assert served.resp_body == "font-content"
    head = Plug.Test.conn(:head, url) |> Volt.DevServer.call(first)
    assert head.status == 200
    assert head.resp_body == ""
    assert (Plug.Test.conn(:get, url) |> Volt.DevServer.call(second)).status == 404

    assert (Plug.Test.conn(:get, "/@volt/assets/arbitrary-path")
            |> Volt.DevServer.call(first)).status == 404

    owner = tables.owner
    monitor = Process.monitor(owner)
    Process.exit(owner, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :killed}
    assert :ets.info(tables.assets) == :undefined
  end
end
