defmodule Volt.JS.HelpersTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Helpers

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-js-helpers-#{System.unique_integer([:positive])}")

    original_format = Application.get_env(:volt, :format)
    original_lint = Application.get_env(:volt, :lint)

    File.mkdir_p!(Path.join(tmp_dir, "format"))
    File.mkdir_p!(Path.join(tmp_dir, "lint"))
    File.write!(Path.join(tmp_dir, "format/source.ts"), "const formatted = true")
    File.write!(Path.join(tmp_dir, "lint/source.ts"), "const linted = true")

    on_exit(fn ->
      restore_env(:format, original_format)
      restore_env(:lint, original_lint)
      File.rm_rf!(tmp_dir)
    end)

    %{tmp_dir: tmp_dir}
  end

  test "discovers tool-specific source sets", %{tmp_dir: tmp_dir} do
    Application.put_env(:volt, :format,
      root: tmp_dir,
      sources: ["format/**/*.ts"],
      ignore: []
    )

    Application.put_env(:volt, :lint,
      root: tmp_dir,
      sources: ["lint/**/*.ts"],
      ignore: []
    )

    assert Helpers.discover_format_files() == [Path.join(tmp_dir, "format/source.ts")]
    assert Helpers.discover_files(tool: :lint) == [Path.join(tmp_dir, "lint/source.ts")]
  end

  defp restore_env(key, nil), do: Application.delete_env(:volt, key)
  defp restore_env(key, value), do: Application.put_env(:volt, key, value)
end
