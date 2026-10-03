defmodule Volt.JS.FormatTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Format

  setup do
    original_config = Application.fetch_env(:volt, :format)

    on_exit(fn ->
      case original_config do
        :error -> Application.delete_env(:volt, :format)
        {:ok, config} -> Application.put_env(:volt, :format, config)
      end
    end)
  end

  test "load_config/1 reads formatter options from the :volt key of .formatter.exs" do
    formatter_opts = [
      plugins: [Volt.Formatter],
      volt: [
        root: ".",
        sources: ["priv/ts/**/*.ts"],
        ignore: ["vendor/**"],
        semi: false,
        print_width: 100
      ]
    ]

    assert Format.load_config(formatter_opts) == [semi: false, print_width: 100]

    assert Format.discovery_config(formatter_opts) == [
             root: ".",
             sources: ["priv/ts/**/*.ts"],
             ignore: ["vendor/**"]
           ]
  end

  test "load_config/1 falls back to JSON config files without a :volt key" do
    assert Format.load_config(plugins: [Volt.Formatter]) == Format.load_json_config()
  end

  test "load_config/0 reads the project's .formatter.exs" do
    assert Format.load_config()[:semi] == false
  end

  test "load_config/1 is unaffected by the build output format" do
    Application.put_env(:volt, :format, :esm)

    assert Format.load_config(volt: [semi: false]) == [semi: false]
  end

  test "formatter options under config :volt, :format are rejected with guidance" do
    Application.put_env(:volt, :format, semi: false)

    assert_raise ArgumentError, ~r/Move them to the `:volt` key of \.formatter\.exs/, fn ->
      Format.load_config(volt: [])
    end

    assert_raise ArgumentError, ~r/\.formatter\.exs/, fn -> Volt.Config.build() end
  end
end
