defmodule Volt.Test.Result do
  @moduledoc "Defines the structured result contract returned by Volt JavaScript test runtimes."

  defmodule Metadata do
    @moduledoc "Metadata collected for a registered JavaScript test before execution."
    use JSONCodec, case: :camel, fast_path: :json

    defstruct [:id, :name, :full_name, :suite, :mode, :skip_reason, tags: [], line: nil]

    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            full_name: String.t(),
            suite: [String.t()],
            mode: :run | :skip | :todo,
            skip_reason: String.t() | nil,
            tags: [String.t()],
            line: pos_integer() | nil
          }
  end

  defmodule SerializedError do
    @moduledoc "Serialized JavaScript error details returned by a failed test."
    use JSONCodec, fast_path: :json

    defstruct [:name, :message, :stack, :expected, :actual]

    @type t :: %__MODULE__{
            name: String.t() | nil,
            message: String.t(),
            stack: String.t() | nil,
            expected: term(),
            actual: term()
          }
  end

  defmodule Test do
    @moduledoc "Execution result for one registered JavaScript test."
    use JSONCodec, case: :camel, fast_path: :json

    defstruct [:id, :name, :full_name, :status, :duration, :error, :skip_reason]

    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            full_name: String.t(),
            status: :passed | :failed | :skipped,
            duration: non_neg_integer(),
            error: SerializedError.t() | nil,
            skip_reason: String.t() | nil
          }
  end

  use JSONCodec, fast_path: :json

  defstruct [:file, :status, :duration, :total, :failed, :skipped, tests: []]

  @type t :: %__MODULE__{
          file: String.t(),
          status: :passed | :failed,
          duration: non_neg_integer(),
          total: non_neg_integer(),
          failed: non_neg_integer(),
          skipped: non_neg_integer(),
          tests: [Test.t()]
        }
end
