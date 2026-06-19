defmodule Volt.Plugin.React do
  @moduledoc """
  Built-in React prebundle coordination for Volt dev mode.
  """

  @behaviour Volt.Plugin

  alias Volt.JS.PrebundleEntry.{Export, Import}

  @impl true
  def name, do: "react"

  @impl true
  def prebundle_alias("react-dom/client"), do: "react"
  def prebundle_alias("react/jsx-runtime"), do: "react"
  def prebundle_alias("react/jsx-dev-runtime"), do: "react"
  def prebundle_alias(_specifier), do: nil

  @impl true
  def prebundle_entry("react") do
    {:proxy, "react.js",
     imports: [Import.default("React", from: "react")],
     exports: [
       Export.default("React"),
       Export.all_from("react"),
       Export.all_from("react-dom/client"),
       Export.all_from("react/jsx-runtime"),
       Export.all_from("react/jsx-dev-runtime")
     ]}
  end

  def prebundle_entry("react-dom") do
    {:proxy, "react-dom.js", exports: [Export.all_from("react-dom")]}
  end

  def prebundle_entry(_specifier), do: nil
end
