defmodule Volt.Test.BundlerTest do
  use ExUnit.Case, async: false

  import Volt.Test.Sigils

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-test-bundler-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "bundles relative TypeScript imports and strips volt:test imports", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "math.ts", ~TS"""
    export function add(left: number, right: number) {
      return left + right
    }
    """)

    entry =
      write!(tmp_dir, "math.test.ts", ~TS"""
      import { test, expect } from 'volt:test'
      import { add } from './math'

      test('adds', () => {
        expect(add(1, 2)).toBe(3)
      })
      """)

    assert {:ok, %Volt.Test.Bundle{entry: ^entry, code: code, sourcemap: sourcemap, files: files}} =
             Volt.Test.Bundler.bundle_file(entry)

    assert is_binary(code)
    assert is_binary(sourcemap)
    assert entry in files
    assert Path.join(tmp_dir, "math.ts") in files
    refute code =~ "volt:test"
    refute code =~ "import { add }"
    assert code =~ "add"
  end

  test "bundles Volt client virtual imports", %{tmp_dir: tmp_dir} do
    entry =
      write!(tmp_dir, "client.test.ts", ~TS"""
      import { test, expect } from 'volt:test'
      import { renderErrorOverlay } from 'volt:client/overlay'
      import { preloadDep } from 'volt:client/preload'

      test('uses client internals', () => {
        expect(typeof renderErrorOverlay).toBe('function')
        expect(typeof preloadDep).toBe('function')
      })
      """)

    assert {:ok, %Volt.Test.Bundle{code: code, files: files}} =
             Volt.Test.Bundler.bundle_file(entry)

    assert code =~ "renderErrorOverlay"
    refute code =~ "volt:client/overlay"
    refute code =~ "volt:client/preload"
    assert Enum.any?(files, &String.ends_with?(&1, "priv/ts/client/overlay.ts"))
    assert Enum.any?(files, &String.ends_with?(&1, "priv/ts/client/preload.ts"))
  end

  test "returns module resolution errors", %{tmp_dir: tmp_dir} do
    entry = write!(tmp_dir, "missing.test.ts", "import './missing'\n")

    assert {:error, {:module_not_found, "./missing", ^entry}} =
             Volt.Test.Bundler.bundle_file(entry)
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
