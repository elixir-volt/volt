defmodule Volt.Dev.ConsoleForwarder do
  @moduledoc false

  require Logger

  @endpoint "/@volt/console"
  @support_modules {:volt, "ts"}

  defmodule Payload do
    @moduledoc false

    use JSONCodec, fast_path: :json

    defstruct [:level, :source, :args]

    @type t :: %__MODULE__{
            level: :log | :info | :warn | :error | :debug,
            source: String.t(),
            args: [term()]
          }
  end

  @spec endpoint() :: String.t()
  def endpoint, do: @endpoint

  @spec inject(String.t()) :: String.t()
  def inject(code) when is_binary(code) do
    Volt.Priv.js!(@support_modules, "dev/console-forwarder.ts") <> "\n" <> code
  end

  @spec log(binary() | Payload.t()) :: :ok
  def log(payload) when is_binary(payload) do
    case Payload.decode(payload) do
      {:ok, payload} -> log(payload)
      {:error, _reason} -> :ok
    end
  end

  def log(%Payload{level: level, args: args, source: source}) do
    message = Enum.map_join(args, " ", &format_arg/1)
    prefix = browser_prefix(source)

    log_message(level, "#{prefix} #{message}")
  end

  def log(_), do: :ok

  defp browser_prefix(""), do: "[Volt][browser]"
  defp browser_prefix(source), do: "[Volt][browser][#{source}]"

  defp format_arg(arg) when is_binary(arg), do: arg
  defp format_arg(arg), do: inspect(arg, pretty: false, limit: :infinity)

  defp log_message(:error, message), do: Logger.error(message)
  defp log_message(:warn, message), do: Logger.warning(message)
  defp log_message(:log, message), do: Logger.info(message)
  defp log_message(:info, message), do: Logger.info(message)
  defp log_message(:debug, message), do: Logger.debug(message)
end
