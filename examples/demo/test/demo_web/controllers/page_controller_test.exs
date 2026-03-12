defmodule DemoWeb.PageControllerTest do
  use DemoWeb.ConnCase

  test "GET / renders counter" do
    conn = get(build_conn(), ~p"/")
    assert html_response(conn, 200) =~ "Volt + PhoenixVapor"
  end
end
