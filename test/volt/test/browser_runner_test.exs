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

  test "browser test modules run concurrently", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "async.browser.test.ts", ~TS"""
    import { test, expect } from 'volt:test'

    test('is registered', () => {
      expect(1).toBe(1)
    })
    """)

    assert [module] =
             Volt.Test.ExUnit.install(
               root: tmp_dir,
               include: ["async.browser.test.ts"],
               browser: true
             )

    assert %{async?: true} = module.__ex_unit__(:config)
  end

  test "tests share the run's browser and get a context each", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "shared.browser.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('starts from an empty page', () => {
        expect(localStorage.getItem('seen')).toBeNull()
        localStorage.setItem('seen', 'yes')
        expect(document.body.dataset.volt).toBeUndefined()
        document.body.dataset.volt = 'seen'
      })
      """)

    config =
      Volt.Test.Config.read(browser: true, include: ["shared.browser.test.ts"], root: tmp_dir)

    assert {:ok, %Result{status: :passed}} =
             Volt.Test.BrowserRunner.run_test(file, 1, config: config)

    {:ok, %{guid: guid}} = Volt.Test.Browser.Run.launch(:chromium, config.timeout)

    assert {:ok, %Result{status: :passed}} =
             Volt.Test.BrowserRunner.run_test(file, 1, config: config)

    assert {:ok, %{guid: ^guid}} = Volt.Test.Browser.Run.launch(:chromium, config.timeout)
  end

  test "bundles a file once until one of its sources changes", %{tmp_dir: tmp_dir} do
    helper = write!(tmp_dir, "answer.ts", "export const answer = 41\n")

    file =
      write!(tmp_dir, "bundled.browser.test.ts", ~TS"""
      import { test, expect } from 'volt:test'
      import { answer } from './answer'

      test('reads the helper', () => {
        expect(answer).toBe(42)
      })
      """)

    config = Volt.Test.Config.read(browser: true, root: tmp_dir)
    bundle_opts = Volt.Test.Shared.bundle_opts(file, config, [])
    {:ok, _pid} = Volt.Test.Browser.start(config)
    {:ok, _browser} = Volt.Test.Browser.Run.launch(:chromium, config.timeout)

    assert {:ok, url} = Volt.Test.Browser.module(file, bundle_opts)
    assert {:ok, ^url} = Volt.Test.Browser.module(file, bundle_opts)

    assert {:ok, %Result{status: :failed}} =
             Volt.Test.BrowserRunner.run_test(file, 1, config: config)

    File.write!(helper, "export const answer = 42\n")
    File.touch!(helper, System.os_time(:second) + 1)

    assert {:ok, next} = Volt.Test.Browser.module(file, bundle_opts)
    assert next != url

    assert {:ok, %Result{status: :passed}} =
             Volt.Test.BrowserRunner.run_test(file, 1, config: config)
  end

  test "collects and runs tests in a browser context", %{tmp_dir: tmp_dir} do
    file =
      write!(tmp_dir, "browser.test.ts", ~TS"""
      import { test, expect } from 'volt:test'

      test('sees browser globals', () => {
        document.body.innerHTML = '<button id="ok">OK</button>'
        const pageURL = new URL(window.location.href)
        expect(pageURL.protocol).toBe('file:')
        expect(pageURL.pathname.endsWith('/index.html')).toBe(true)
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
