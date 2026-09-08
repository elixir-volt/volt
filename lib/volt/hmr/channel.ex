defmodule Volt.HMR.Channel do
  @moduledoc "Registry channel identity for development-session subscribers."

  def key(:default), do: :clients
  def key(session), do: {:clients, session}
end
