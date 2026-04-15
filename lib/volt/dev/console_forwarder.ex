defmodule Volt.Dev.ConsoleForwarder do
  @moduledoc false

  require Logger

  @endpoint "/@volt/console"

  @spec endpoint() :: String.t()
  def endpoint, do: @endpoint

  @spec inject(String.t()) :: String.t()
  def inject(code) when is_binary(code) do
    Volt.JS.Asset.compiled!("dev-console-forwarder.ts") <> "\n" <> code
  end

  @spec log(binary() | map()) :: :ok
  def log(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, map} when is_map(map) -> log(map)
      _ -> :ok
    end
  end

  def log(%{"level" => level, "args" => args, "source" => source}) when is_list(args) do
    message = Enum.join(Enum.map(args, &format_arg/1), " ")
    prefix = if source in [nil, ""], do: "[Volt][browser]", else: "[Volt][browser][#{source}]"

    case normalize_level(level) do
      :error -> Logger.error("#{prefix} #{message}")
      :warning -> Logger.warning("#{prefix} #{message}")
      :info -> Logger.info("#{prefix} #{message}")
      :debug -> Logger.debug("#{prefix} #{message}")
    end

    :ok
  end

  def log(_), do: :ok

  defp format_arg(arg) when is_binary(arg), do: arg
  defp format_arg(arg), do: inspect(arg, pretty: false, limit: :infinity)

  defp normalize_level("error"), do: :error
  defp normalize_level(:error), do: :error
  defp normalize_level("warn"), do: :warning
  defp normalize_level(:warn), do: :warning
  defp normalize_level("info"), do: :info
  defp normalize_level(:info), do: :info
  defp normalize_level("debug"), do: :debug
  defp normalize_level(:debug), do: :debug
  defp normalize_level(_), do: :info
end
