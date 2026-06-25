defmodule Volt.HMRTest do
  use ExUnit.Case, async: false

  setup do
    Registry.register(Volt.HMR.Registry, :clients, nil)
    :ok
  end

  test "broadcast sends HMR messages to connected clients" do
    assert :ok = Volt.HMR.broadcast(:update, %{path: "index.html", changes: ["full"]})

    assert_receive {:volt_hmr, :update, %{path: "index.html", changes: ["full"]}}
  end

  test "update normalizes change atoms" do
    assert :ok = Volt.HMR.update("index.html", [:hmr], boundary: "/assets/app.ts", timestamp: 123)

    assert_receive {:volt_hmr, :update,
                    %{
                      path: "index.html",
                      changes: ["hmr"],
                      boundary: "/assets/app.ts",
                      timestamp: 123
                    }}
  end

  test "full_reload and style_update broadcast update payloads" do
    assert :ok = Volt.HMR.full_reload("index.html")
    assert_receive {:volt_hmr, :update, %{path: "index.html", changes: ["full"]}}

    assert :ok = Volt.HMR.style_update("app.css")
    assert_receive {:volt_hmr, :update, %{path: "app.css", changes: ["style"]}}
  end

  test "error broadcasts error payload" do
    assert :ok = Volt.HMR.error("index.html", "boom")
    assert_receive {:volt_hmr, :error, %{path: "index.html", reason: "boom"}}
  end
end
