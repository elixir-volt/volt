defmodule Volt.Dev.Session.CallTest do
  use ExUnit.Case, async: true

  test "a terminated supervisor returns a retryable result" do
    {:ok, supervisor} = Volt.Dev.Session.Supervisor.start_link([])
    Supervisor.stop(supervisor)
    assert {:error, :session_restarting} = Volt.Dev.Session.Supervisor.tables(supervisor)
    assert {:error, :session_restarting} = Volt.Dev.Session.Supervisor.stylesheet(supervisor)
  end

  test "unrelated exits and exceptions remain visible" do
    assert catch_exit(Volt.Dev.Session.Call.run(fn -> exit(:unexpected) end)) == :unexpected
    assert_raise ArgumentError, fn -> Volt.Dev.Session.Call.run(fn -> raise ArgumentError end) end
  end
end
