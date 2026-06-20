defmodule Volt.HMR.Message do
  @moduledoc """
  JSON message sent over the HMR WebSocket protocol.

  Uses `JSONCodec` for struct<->JSON (de)serialization. `Jason` is still used
  for the final binary encoding of the dumped map.

  ## Wire types

    * `update` — an HMR update payload (`path`, `changes`, optional `boundary`, `timestamp`)
    * `error` — a build/runtime error to surface in the overlay
    * `ping` — heartbeat sent by the browser client
    * `pong` — heartbeat reply from the server

  """

  use JSONCodec

  @type t :: %__MODULE__{
          type: :update | :error | :ping | :pong,
          payload: term() | nil
        }

  defstruct type: nil, payload: nil
end
