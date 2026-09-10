defmodule Volt.Tailwind.ResolveError do
  @moduledoc "A failed file resolution with the exact candidates attempted by the resolver."
  defexception [:message, candidates: []]
end
