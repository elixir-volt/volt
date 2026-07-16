defmodule Volt.JS.FormatTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Format

  setup do
    original_config = Application.get_env(:volt, :format)

    on_exit(fn ->
      case original_config do
        nil -> Application.delete_env(:volt, :format)
        config -> Application.put_env(:volt, :format, config)
      end
    end)
  end

  test "load_config/0 excludes file-discovery options from OXC formatter options" do
    Application.put_env(:volt, :format,
      root: ".",
      sources: ["priv/ts/**/*.ts"],
      ignore: ["vendor/**"],
      semi: false,
      print_width: 100
    )

    assert Format.load_config() == [semi: false, print_width: 100]
  end
end
