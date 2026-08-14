# JavaScript and TypeScript Testing

Volt can register JavaScript and TypeScript test files as ordinary ExUnit tests. You still run one command:

```bash
mix test
```

The JS/TS runner is Volt-native: test files are bundled with OXC, executed in QuickBEAM, and reported through ExUnit. There is no separate `mix volt.test` command and no Vitest/Node process to manage.

## Setup

Add the Volt test installer to `test/test_helper.exs` after `ExUnit.start/1`:

```elixir
ExUnit.start(exclude: [:integration])

Volt.Test.ExUnit.install()
```

By default, Volt looks under `assets/` for:

```text
**/*.{test,spec}.{js,ts,jsx,tsx}
```

Configure discovery with `config :volt, :test`:

```elixir
config :volt, :test,
  root: "assets",
  include: ["**/*.{test,spec}.{js,ts,jsx,tsx}"],
  exclude: ["vendor/**", "node_modules/**"],
  timeout: 30_000
```

Test files are bundled with `Volt.Builder.bundle/1`, so the `bundle:` key accepts normal Volt build graph options such as `:plugins`, `:aliases`, `:node_modules`, `:resolve_dirs`, `:loaders`, and `:define`:

```elixir
config :volt, :test,
  root: "assets",
  bundle: [
    plugins: [Volt.Plugin.React],
    aliases: %{"@" => "assets/js"}
  ]
```

Use `bundle:` for source-graph concerns and the top-level test options for discovery/execution concerns.

Use `setup_files` for modules that must execute before every test module. Relative paths resolve from the configured test `root`:

```elixir
config :volt, :test,
  root: "assets",
  setup_files: ["test/setup.ts"]
```

Setup files share the bundled module graph with the test, so they can install globals, register matchers, or import application test support without a separate runtime.

You can also pass options directly from `test/test_helper.exs`, which is useful for package dogfood tests or custom fixture roots:

```elixir
Volt.Test.ExUnit.install(
  root: "test/volt/test/fixtures",
  include: ["core_api.test.ts"]
)
```

By default, each JavaScript `test(...)` is registered as an individual ExUnit test. Large suites can execute once per file instead:

```elixir
Volt.Test.ExUnit.install(granularity: :file)
```

File granularity keeps file-level ExUnit reporting and JavaScript failure details while avoiding a separate bundle and runtime invocation for every test. It also tags browser-backed files with `browser_js: true`.

Profile-specific configuration follows the rest of Volt:

```elixir
config :volt, :my_app_web,
  test: [root: "apps/my_app_web/assets", include: ["**/*.test.ts"]]
```

Then install that profile:

```elixir
Volt.Test.ExUnit.install(profile: :my_app_web)
```

## Writing tests

Import the Vitest-like API from `volt:test`:

```javascript
import { describe, test, expect, beforeEach, afterEach } from 'volt:test'
import { add } from './math'

describe('add', () => {
  beforeEach(() => {
    // setup
  })

  test('adds numbers', () => {
    expect(add(1, 2)).toBe(3)
  })
})
```

Async tests can return promises or use `async` functions:

```javascript
test('loads data', async () => {
  const value = await Promise.resolve(42)
  expect(value).toBe(42)
})
```

Relative imports are bundled before execution:

```javascript
import { frameworkName } from './support'

test('uses helper module', () => {
  expect(frameworkName).toContain('volt')
})
```

## Inline ExUnit assertions

For small checks that belong next to ordinary Elixir tests, use `Volt.Test.Case` and assert against a JavaScript-like sigil:

```elixir
defmodule MyApp.FrontendTest do
  use Volt.Test.Case, async: false

  test "formats a label" do
    assert ~TS"""
    const label: string = "hello volt"

    expect(label.toUpperCase()).toBe("HELLO VOLT")
    """
  end
end
```

`Volt.Test.Case` keeps normal ExUnit assertions working and adds inline support for `~JS`, `~TS`, `~JSX`, and `~TSX`. The snippet is wrapped as one Volt JavaScript test. Top-level imports stay top-level, so snippets can import application code:

```elixir
defmodule MyApp.CounterTest do
  use Volt.Test.Case, async: false

  test "uses app code" do
    assert ~TS"""
    import { label } from "app/counter"

    expect(label()).toBe("Count")
    """
  end
end
```

Inline assertions use the same global `config :volt, :test` settings as file-based tests. Put aliases and framework plugins in `config/test.exs` when they are shared:

```elixir
config :volt, :test,
  bundle: [
    aliases: %{"app" => "assets/js"},
    plugins: [Volt.Plugin.React]
  ]
```

Module-level options are useful when a group of inline assertions needs a different environment:

```elixir
defmodule MyApp.BrowserSnippetTest do
  use Volt.Test.Case, async: false, browser: true

  test "updates the DOM" do
    assert ~TS"""
    document.body.innerHTML = "<button>Save</button>"

    expect(document.querySelector("button")?.textContent).toBe("Save")
    """
  end
end
```

Use file-based tests for larger JS suites, repeated setup, or behavior that is primarily owned by browser code. Use inline assertions for compact checks that read better inside an ExUnit module.

## Test and suite modifiers

Skip or mark tests as TODO:

```javascript
test.skip('not ready yet', () => {
  throw new Error('will not run')
})

test.todo('add coverage for browser behavior')
```

Suites support the same modifiers:

```javascript
describe.skip('external service', () => {
  test('calls service', () => {
    // skipped
  })
})

describe.todo('future behavior', () => {
  test('documents planned coverage')
})
```

You can also skip dynamically from the test context:

```javascript
test('platform-specific behavior', ({ skip }) => {
  skip(!navigator.userAgent.includes('Firefox'), 'Firefox only')
  expect(true).toBe(true)
})
```

## Parameterized tests

Use `test.each` for table-driven tests:

```javascript
test.each([
  [1, 2, 3],
  [2, 3, 5]
])('adds %d + %d = %d', (left, right, total) => {
  expect(Number(left) + Number(right)).toBe(total)
})
```

Use `describe.each` to repeat a suite for multiple values:

```javascript
describe.each(['en', 'fr'])('locale %s', (locale) => {
  test('has a locale code', () => {
    expect(String(locale)).toHaveLength(2)
  })
})
```

Supported placeholders in each-test names are `%s`, `%d`, `%i`, `%f`, `%j`, and `%o`.

## Matchers

Volt includes a small core matcher set:

```javascript
expect(value).toBe(expected)
expect(value).toEqual(expected)
expect(value).toContain(expected)
expect(value).toMatch(/pattern/)
expect(value).toHaveLength(3)
expect(value).toHaveProperty('nested.value', 42)
expect(value).toBeDefined()
expect(value).toBeUndefined()
expect(value).toBeTruthy()
expect(value).toBeFalsy()
expect(value).toBeNull()
expect(value).toBeNaN()
expect(value).toBeCloseTo(0.3, 5)
expect(value).toBeGreaterThan(1)
expect(value).toBeGreaterThanOrEqual(1)
expect(value).toBeLessThan(10)
expect(value).toBeLessThanOrEqual(10)
expect(fn).toThrow('message')
```

All matchers support `.not`:

```javascript
expect('volt').not.toContain('vite')
expect(1 + 1).not.toBe(3)
```

## Browser tests

Use `browser: true` when tests need real browser globals such as `window`, `document`, layout APIs, or DOM events:

```elixir
Volt.Test.ExUnit.install(
  root: "test/browser",
  include: ["**/*.test.ts"],
  browser: true
)
```

Browser tests still use the same `volt:test` API and still register one ExUnit test per JS `test(...)`. They are best suited for browser-owned runtime behavior such as DOM helpers, client preload logic, and other code that needs real browser globals. Keep Elixir-owned behavior such as manifests, Plug responses, cache state, and build output in ordinary ExUnit tests.

```javascript
import { test, expect } from 'volt:test'

test('updates the DOM', () => {
  document.body.innerHTML = '<button id="save">Save</button>'
  expect(document.querySelector('#save')?.textContent).toBe('Save')
})
```

Volt runs these tests through PlaywrightEx. Install Playwright for local browser execution:

```bash
npm install --save-dev playwright
npx playwright install chromium
```

By default Volt uses `node_modules/playwright/cli.js` when present, otherwise `playwright` from `PATH`. Pass PlaywrightEx supervisor options with `playwright: [...]` if your executable lives elsewhere.

## ExUnit integration

Each collected JS/TS `test(...)` becomes an ExUnit test. That means normal ExUnit filtering, formatters, failures, and CI behavior continue to work.

Volt adds useful tags:

- `:js` — JS/TS test generated by Volt
- `:volt_file` — source test file path
- `:volt_test_id` — collected test id inside the file
- `:volt_tags` — tags passed from JS test options

For example:

```javascript
test('slow calculation', { tags: ['slow'] }, () => {
  expect(1 + 1).toBe(2)
})
```

Skipped and TODO tests are registered as skipped ExUnit tests, so they are visible in normal ExUnit output.

## ExUnit fixture sigils

When an Elixir test needs readable JS/TS input, import `Volt.Test.Sigils`:

```elixir
import Volt.Test.Sigils

source = ~TS"""
export const answer: number = 42
"""
```

Use the `v` modifier to parse-check a snippet with OXC:

```elixir
source = ~TS"export const value: string = 'ok'"v
```

Available sigils: `~JS`, `~TS`, `~JSX`, `~TSX`, `~CSS`, and `~HTML`.

## Current scope

The QuickBEAM runner is intended for fast JS/TS unit tests. The browser runner is intended for tests that genuinely need a browser environment. Higher-level Phoenix end-to-end flows can still use PlaywrightEx or Phoenix-oriented browser-test helpers alongside Volt's JS test runner.
