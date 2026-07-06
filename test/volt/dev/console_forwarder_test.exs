defmodule Volt.Dev.ConsoleForwarderTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "injects forwarding preamble" do
    code = Volt.Dev.ConsoleForwarder.inject("console.log('ok')")
    assert code =~ "__voltConsoleForwarderInstalled"
    assert code =~ "console.log('ok')"
  end

  test "logs browser payload JSON" do
    payload =
      Jason.encode!(%{
        level: "error",
        source: "/assets/app.js",
        args: ["boom", %{"code" => 500}]
      })

    log = capture_log(fn -> Volt.Dev.ConsoleForwarder.log(payload) end)

    assert log =~ "[Volt][browser][/assets/app.js] boom %{\"code\" => 500}"
  end

  test "rejects payloads outside the strict console contract" do
    log =
      capture_log(fn ->
        Volt.Dev.ConsoleForwarder.log(~s({"level":"trace","source":"/","args":[]}))
      end)

    assert log == ""
  end
end
