defmodule Volt.Dev.ConsoleForwarderTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "injects forwarding preamble" do
    code = Volt.Dev.ConsoleForwarder.inject("console.log('ok')")
    assert code =~ "__voltConsoleForwarderInstalled"
    assert code =~ "console.log('ok')"
  end

  test "logs browser payloads" do
    log =
      capture_log(fn ->
        Volt.Dev.ConsoleForwarder.log(%{
          "level" => "error",
          "source" => "/assets/app.js",
          "args" => ["boom", %{"code" => 500}]
        })
      end)

    assert log =~ "[Volt][browser][/assets/app.js] boom %{\"code\" => 500}"
  end
end
