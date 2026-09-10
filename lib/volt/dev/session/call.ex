defmodule Volt.Dev.Session.Call do
  @moduledoc "Translate disappearing session processes into a retryable lifecycle result."

  def run(fun) do
    fun.()
  catch
    :exit, {reason, {GenServer, :call, _}} when reason in [:noproc, :normal, :shutdown] ->
      {:error, :session_restarting}

    :exit, {{:shutdown, _}, {GenServer, :call, _}} ->
      {:error, :session_restarting}
  end
end
