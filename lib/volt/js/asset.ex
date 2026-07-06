defmodule Volt.JS.Asset do
  @moduledoc "Compatibility accessors for JavaScript and TypeScript support assets bundled with Volt."

  @assets {:volt, "ts"}
  @runtime_rewrites %{"../hmr" => "/@volt/client.js"}

  @doc "Path to the priv/ts directory containing bundled TypeScript assets."
  @spec priv_dir :: String.t()
  def priv_dir, do: Volt.Priv.path(:volt, "ts")

  @spec read!(String.t()) :: String.t()
  def read!(filename), do: Volt.Priv.read!(@assets, filename)

  @doc "Read a support asset, emit browser JavaScript, and cache static modules."
  @spec compiled!(String.t()) :: String.t()
  def compiled!(filename), do: Volt.Priv.js!(@assets, filename)

  @doc "Emit browser JavaScript after binding OXC `$placeholder` literals."
  @spec compiled_template!(String.t(), keyword() | map()) :: String.t()
  def compiled_template!(filename, bindings) do
    Volt.Priv.js!(@assets, filename, bindings, rewrite_specifiers: @runtime_rewrites)
  end

  @spec path_for(String.t()) :: String.t()
  def path_for(filename), do: Volt.Priv.path(@assets, filename)
end
