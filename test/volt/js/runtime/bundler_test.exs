defmodule Volt.JS.Runtime.BundlerTest do
  use ExUnit.Case, async: true

  alias Volt.JS.Runtime.Bundler

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "volt-runtime-bundler-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(tmp_dir, "app"))
    File.mkdir_p!(Path.join(tmp_dir, "shims"))

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "rewrites configured Node builtin requires to bundled shims", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "app/entry.ts")
    shim = Path.join(tmp_dir, "shims/assert.cjs")

    File.write!(entry, """
    const assert = require('assert')
    assert.equal(1, '1')
    export const ok = true
    """)

    File.write!(shim, """
    module.exports = {
      equal(left, right) {
        if (left != right) throw new Error('not equal')
      }
    }
    """)

    assert {:ok, code} =
             Bundler.bundle_file(entry,
               builtin_shims: %{"assert" => shim},
               format: :esm
             )

    refute code =~ ~s|require("assert")|
    assert code =~ "not equal"
    assert code =~ "const ok = true"
  end

  test "leaves unconfigured Node builtins external", %{tmp_dir: tmp_dir} do
    entry = Path.join(tmp_dir, "app/entry.ts")

    File.write!(entry, """
    const assert = require('assert')
    assert.ok(true)
    """)

    assert {:ok, code} = Bundler.bundle_file(entry, format: :esm)

    assert code =~ ~s|("assert").ok(true)|
    assert code =~ "typeof require"
  end
end
