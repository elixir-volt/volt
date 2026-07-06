defmodule Volt.Test.Config do
  @moduledoc """
  Normalized Volt test runner configuration.

  Configuration follows Volt's existing flat/profile style:

      config :volt, :test,
        root: "assets",
        include: ["**/*.{test,spec}.{js,ts,jsx,tsx}"],
        exclude: ["vendor/**", "node_modules/**"],
        bundle: [plugins: [Volt.Plugin.React]]

      config :volt, :my_app_web,
        test: [root: "apps/my_app_web/assets"]

  Profile-specific test options override global `config :volt, :test` values.
  Explicit overrides win over both.
  """

  defstruct root: Volt.Paths.assets(),
            include: ["**/*.{test,spec}.{js,ts,jsx,tsx}"],
            exclude: ["vendor/**", "node_modules/**" | Volt.Paths.ignored_globs()],
            setup_files: [],
            browser: false,
            browsers: [:chromium],
            timeout: 30_000,
            bundle: [],
            js_runtime: [],
            playwright: []

  @type t :: %__MODULE__{
          root: String.t(),
          include: [String.t()],
          exclude: [String.t()],
          setup_files: [String.t()],
          browser: boolean(),
          browsers: [atom()],
          timeout: timeout(),
          bundle: keyword(),
          js_runtime: keyword(),
          playwright: keyword()
        }

  @keys [
    :root,
    :include,
    :exclude,
    :setup_files,
    :browser,
    :browsers,
    :timeout,
    :bundle,
    :js_runtime,
    :playwright
  ]

  @spec read(atom() | keyword()) :: t()
  def read(profile_or_overrides \\ [])

  def read(profile) when is_atom(profile), do: read(profile, [])
  def read(overrides) when is_list(overrides), do: read(nil, overrides)

  @spec read(atom() | nil, keyword()) :: t()
  def read(profile, overrides) do
    global_env = Application.get_env(:volt, :test, [])

    profile_env =
      if profile do
        :volt
        |> Application.get_env(profile, [])
        |> Keyword.get(:test, [])
      else
        []
      end

    __MODULE__
    |> struct!()
    |> Map.from_struct()
    |> Map.merge(take_config(global_env))
    |> Map.merge(take_config(profile_env))
    |> Map.merge(take_config(overrides))
    |> then(&struct!(__MODULE__, &1))
  end

  defp take_config(config) when is_list(config) do
    config
    |> Keyword.take(@keys)
    |> Map.new()
  end
end
