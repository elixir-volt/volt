defmodule Volt.Tailwind.CompileError do
  @moduledoc "Compiler failure retaining dependencies needed to observe recovery."
  defexception [:message, dependencies: []]
end
