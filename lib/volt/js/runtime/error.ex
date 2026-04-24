defmodule Volt.JS.Runtime.Error do
  @moduledoc false

  defexception [:message, :reason, :stage]

  @type t :: %__MODULE__{message: String.t(), reason: term(), stage: atom() | nil}

  @impl true
  def exception(opts) do
    stage = Keyword.get(opts, :stage)
    reason = Keyword.get(opts, :reason)
    message = Keyword.get(opts, :message) || format_message(stage, reason)
    %__MODULE__{message: message, reason: reason, stage: stage}
  end

  defp format_message(nil, reason), do: "JS runtime error: #{inspect(reason)}"
  defp format_message(stage, reason), do: "JS runtime #{stage} failed: #{inspect(reason)}"
end
