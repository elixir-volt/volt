defmodule Volt.JS.DiscoveryTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Discovery

  setup do
    tmp_dir =
      Path.expand(
        "volt-js-discovery-#{System.unique_integer([:positive])}",
        System.tmp_dir!()
      )

    original_env =
      Map.new([:format, :lint, :root, :sources, :ignore], fn key ->
        {key, Application.fetch_env(:volt, key)}
      end)

    File.mkdir_p!(Path.join(tmp_dir, "format"))
    File.mkdir_p!(Path.join(tmp_dir, "lint"))
    File.write!(Path.join(tmp_dir, "format/source.ts"), "const formatted = true")
    File.write!(Path.join(tmp_dir, "lint/source.ts"), "const linted = true")

    on_exit(fn ->
      Enum.each(original_env, fn {key, value} -> restore_env(key, value) end)
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

    assert Discovery.format_files() == [Path.join(tmp_dir, "format/source.ts")]
    assert Discovery.files(tool: :lint) == [Path.join(tmp_dir, "lint/source.ts")]
  end

  test "a bundle format on the same key holds no discovery options", %{tmp_dir: tmp_dir} do
    Application.put_env(:volt, :format, :esm)
    Application.put_env(:volt, :root, tmp_dir)
    Application.put_env(:volt, :sources, ["format/**/*.ts"])
    Application.put_env(:volt, :ignore, [])

    Application.put_env(:volt, :lint,
      root: tmp_dir,
      sources: ["lint/**/*.ts"],
      ignore: []
    )

    assert Discovery.format_files() == [Path.join(tmp_dir, "format/source.ts")]
    assert Discovery.files(tool: :lint) == [Path.join(tmp_dir, "lint/source.ts")]
  end

  defp restore_env(key, :error), do: Application.delete_env(:volt, key)
  defp restore_env(key, {:ok, value}), do: Application.put_env(:volt, key, value)
end
