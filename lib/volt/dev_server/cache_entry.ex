defmodule Volt.DevServer.CacheEntry do
  @moduledoc "Cached development-server compilation result."

  defstruct code: "",
            sourcemap: nil,
            css: nil,
            hashes: nil,
            content_type: Volt.MIME.javascript(),
            vendor_hash: nil

  @type t :: %__MODULE__{
          code: String.t(),
          sourcemap: String.t() | nil,
          css: String.t() | nil,
          hashes: Volt.Pipeline.Result.Hashes.t() | nil,
          content_type: String.t(),
          vendor_hash: String.t() | nil
        }
end
