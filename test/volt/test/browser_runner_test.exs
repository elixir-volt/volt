defmodule Volt.Test.BrowserRunnerTest do
  use ExUnit.Case, async: false

  import Volt.Test.Sigils

  alias Volt.Test.Result

  @moduletag :integration

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-browser-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "ExUnit install registers and runs browser tests", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "install.browser.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('runs through ExUnit', () => {
        document.body.dataset.volt = 'browser'
        expect(document.body.dataset.volt).toBe('browser')
      })
      """)

    assert [module] =
             Volt.Test.ExUnit.install(
               root: tmp_dir,
               include: ["install.browser.test.ts"],
               browser: true
             )

    [%ExUnit.Test{name: name, tags: tags}] = module.__ex_unit__().tests
    assert tags.volt_file == file
    assert :ok = apply(module, name, [%{}])
  end

  test "collects and runs tests in a browser context", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "browser.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('sees browser globals', () => {
        document.body.innerHTML = '<button id="ok">OK</button>'
        expect(window.location.href).toMatch('about:blank')
        expect(document.querySelector('#ok')?.textContent).toBe('OK')
      })
      """)

    config = Volt.Test.Config.read(browser: true, include: ["browser.test.ts"], root: tmp_dir)

    assert {:ok, [%Result.Metadata{full_name: "sees browser globals", line: 3}]} =
             Volt.Test.BrowserRunner.collect_file(file, config: config)

    assert {:ok, %Result{status: :passed, failed: 0}} =
             Volt.Test.BrowserRunner.run_test(file, 1, config: config)
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end
end
