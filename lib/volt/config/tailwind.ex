defmodule Volt.Config.Tailwind do
  @moduledoc "Normalized Tailwind CSS root configuration."

  @enforce_keys [:name, :sources]
  defstruct [:css, :name, :sources, :dev_url]

  @type source :: %{
          required(:base) => String.t(),
          required(:pattern) => String.t(),
          optional(:negated) => boolean()
        }
  @type t :: %__MODULE__{
          css: String.t() | nil,
          name: String.t(),
          sources: [source()],
          dev_url: String.t()
        }

  @spec enabled?(keyword() | boolean() | nil) :: boolean()
  def enabled?(true), do: true
  def enabled?(config), do: is_list(config) and config != []

  @spec new(keyword() | boolean() | nil, keyword()) :: t()
  def new(config, overrides \\ [])
  def new(config, overrides) when config in [nil, false, true], do: new([], overrides)

  def new(config, overrides) when is_list(config) do
    css = overrides[:css] || config[:css]
    name = overrides[:name] || config[:name] || entry_name(css)

    %__MODULE__{
      css: if(css, do: Path.expand(css)),
      name: name,
      sources: overrides[:sources] || config[:sources] || [],
      dev_url: overrides[:dev_url] || config[:dev_url] || default_dev_url(name)
    }
  end

  defp entry_name(nil), do: "app"
  defp entry_name(css), do: css |> Path.basename() |> Path.rootname()
  defp default_dev_url(name), do: "/assets/css/#{name}.css"
end
