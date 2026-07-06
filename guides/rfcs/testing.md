# RFC: Volt Test Framework

## Status

Draft proposal.

## Goal

Add a Volt-native test runner with a Vitest-like JavaScript/TypeScript authoring experience while keeping ExUnit as the orchestration, filtering, reporting, and CI integration layer.

The runner should support:

- regular ExUnit `.exs` tests;
- JS/TS module tests such as `*.test.ts`, `*.spec.ts`, `*.test.tsx`, and framework-adjacent tests;
- optional browser tests powered by PlaywrightEx;
- `mix test`-friendly failure semantics and tags;
- Volt idioms: Elixir config, OXC/QuickBEAM runtime, no Node/Vitest process requirement.

## Non-goals

- Reimplement all Vitest APIs in the first iteration.
- Replace ExUnit.
- Require PlaywrightEx for non-browser JS tests.
- Require Node.js for the core JS/TS test runner.

## Existing Volt fit

Volt already has most of the primitives needed:

- `Volt.Config` establishes flat and named-profile configuration patterns.
- `Volt.JS.Helpers.discover_files/1` provides glob-based JS/TS discovery.
- `Volt.JS.Runtime` starts isolated QuickBEAM runtimes with materialized TS assets from `priv/ts` and optional bundling.
- `Volt.JS.Runtime` supports Elixir handlers exposed to JS via `Beam.call`/`Beam.callSync`.
- `Volt.Pipeline` and the dev server already compile TS, JSX, framework files, virtual modules, assets, and plugin output.
- Test support currently follows normal ExUnit organization: `test/test_helper.exs`, `test/volt/**`, and Mix task tests under `test/mix/tasks/**`.

## User-facing API

### ExUnit entry point

Volt should keep `mix test` as the single test command. JS/TS tests are wired into ExUnit from `test/test_helper.exs`:

```elixir
ExUnit.start(exclude: [:integration])
Volt.Test.ExUnit.install()
```

This avoids a parallel test route. ExUnit remains responsible for filtering, formatters, tags, failures, and CI behavior.

### Config

Follow the existing `config :volt` style:

```elixir
config :volt, :test,
  include: ["**/*.{test,spec}.{js,ts,jsx,tsx}"],
  exclude: ["vendor/**", "node_modules/**"],
  root: "assets",
  setup_files: ["assets/test/setup.ts"],
  browser: false,
  browsers: [:chromium],
  timeout: 30_000,
  js_runtime: [apis: [:browser, :node]],
  playwright: [timeout: 5_000]
```

For named profiles, mirror `Volt.Config.build/2`:

```elixir
config :volt, :my_app_web,
  test: [root: "apps/my_app_web/assets", include: ["**/*.test.ts"]]
```

### JS/TS authoring API

Core module exposed by Volt:

```ts
import { describe, test, expect, beforeEach, afterEach } from "volt:test"

describe("sum", () => {
  test("adds numbers", () => {
    expect(1 + 2).toBe(3)
  })
})
```

Browser tests should use explicit fixtures:

```ts
import { test, expect } from "volt:test/browser"

test("homepage", async ({ page }) => {
  await page.goto("/")
  await expect(page.locator("h1")).toHaveText("Welcome")
})
```

### ExUnit authoring API

`.exs` tests stay normal. Volt also provides source fixture sigils for JS-heavy ExUnit tests:

```elixir
import Volt.Test.Sigils

source = ~TS"""
const value: number = 42
"""

valid_source = ~TS"export const value: number = 42"v
```

The sigils are fixture helpers, not a replacement for JS/TS test files. They are useful when an Elixir test exercises a Volt compiler, transform, resolver, or plugin API and needs readable JS/TS input.

`.exs` tests stay normal:

```elixir
defmodule MyApp.SomeTest do
  use ExUnit.Case, async: true

  test "works" do
    assert 1 + 1 == 2
  end
end
```

Browser tests from Elixir can opt into a Volt case template:

```elixir
defmodule MyApp.BrowserTest do
  use Volt.Test.BrowserCase, async: false

  test "homepage", %{page: page} do
    assert {:ok, _} = Volt.Test.Page.goto(page, "/")
  end
end
```

## Architecture

### Modules

Proposed modules:

- `Volt.Test.Config` — reads `config :volt, :test`, including named profiles. Implemented as the initial wiring layer.
- `Volt.Test.Discovery` — discovers JS/TS test files using Volt-style glob handling. Implemented as the initial wiring layer.
- `Volt.Test.Manifest` — normalized representation of files, suites, tests, tags, and browser requirements.
- `Volt.Test.Bundle` — Elixir-owned executable bundle metadata (`code`, `sourcemap`, `files`, `entry`) kept separate from JS runner result maps.
- `Volt.Test.Runner` — executes JS/TS tests in QuickBEAM and returns structured results. Initial implementation supports `volt:test` imports and local relative JS/TS module graphs.
- `Volt.Test.Assertions` — converts JS assertion failures into ExUnit failures. Initial implementation formats first failed JS test as an ExUnit failure.
- `Volt.Test.JSCase` — ExUnit bridge used by generated wrapper modules.
- `Volt.Test.BrowserCase` — optional ExUnit case template for PlaywrightEx-backed tests.
- `Volt.Test.Playwright` — supervision and lifecycle wrapper around PlaywrightEx.
- `Volt.Test.Page` / `Volt.Test.Locator` — small Elixir facade over PlaywrightEx for browser assertions.
- `Volt.Test.ExUnit` — ExUnit integration entry point. Initial implementation discovers JS/TS tests, generates one ExUnit bridge module per file, and keeps `mix test` as the only test command.

Runtime assets and types:

- `priv/ts/test/core.ts` — runtime entry that installs the `volt:test` globals. The implementation is split into focused modules for API registration, matcher behavior, state, errors, formatting, and runner protocol. Initial implementation provides `describe`, `describe.skip`, `describe.todo`, `test`, `test.skip`, `test.todo`, hooks, context `skip`, and `expect`, dogfooded by `test/volt/test/fixtures/core_api.test.ts` importing a relative fixture module.
- `priv/types/test/volt-test.d.ts` — canonical `volt:test` type contract, including the shared `Volt.Test` namespace used by the runtime implementation so the API shape is not duplicated between implementation and ambient module declarations.
- `priv/types/internal/support-globals.d.ts` — private Volt support-module globals such as `$css` and `$mod_url`.
- `priv/types/client/hmr.d.ts` — app-facing HMR browser globals.
- `priv/types/frameworks/*.d.ts` — framework/compiler-specific declaration shims split per framework.
- `priv/ts/test/runner.ts` — collection/execution protocol used by `Volt.Test.Runner` and imported by the `core.ts` entry.
- Future `volt:test/browser` runtime assets — browser fixture API and JS proxies for Playwright commands.

### Execution model

Use ExUnit as the root runner.

Initial implementation can use one ExUnit test per JS/TS file:

1. `Volt.Test.ExUnit.install/1` discovers JS/TS test files from `test/test_helper.exs`.
2. It defines transient ExUnit bridge modules in memory.
3. Each generated module uses `ExUnit.Case` directly.
4. Each generated ExUnit test calls `Volt.Test.Runner.run_file/2`.
5. The runner returns `:ok` or a structured failure containing file, suite path, test name, message, stack, expected, actual, and source location.
6. `Volt.Test.Assertions` raises an ExUnit assertion/error with readable output.

A later enhancement can add collection-first per-test ExUnit integration:

1. QuickBEAM performs a collection pass for each JS/TS test file.
2. Volt generates one ExUnit `test` per collected JS `test(...)`.
3. Each ExUnit test re-enters the runner with `{file, test_id}`.

This gives perfect ExUnit filtering/reporting, but collection must avoid surprising module side effects. One-file-per-ExUnit-test is the safer MVP.

### Compilation and module resolution

JS/TS tests should go through Volt’s existing pipeline where possible instead of a bespoke transpiler:

- TS/JSX syntax: OXC/Volt pipeline.
- aliases and tsconfig paths: `Volt.Config.build/2`.
- framework files: existing plugin hooks.
- assets and virtual modules: existing pipeline behavior where practical.

The runner should provide virtual module resolution for:

- `volt:test`
- `volt:test/browser`

This can be implemented as a built-in Volt test plugin or as a runner-specific resolver before bundling.

### QuickBEAM runtime

Use `Volt.JS.Runtime` rather than direct `QuickBEAM.start/1` so tests share Volt’s package isolation and runtime asset materialization.

Suggested runtime options:

```elixir
Volt.JS.Runtime.ensure!(
  name: {:global, {:volt_test_runtime, profile}},
  entry: {:external_path, Volt.Priv.path({:volt, "ts"}, "test/core.ts")},
  bundle: true,
  bundle: true,
  apis: [:browser, :node],
  handlers: Volt.Test.Runner.handlers(context)
)
```

Handlers should cover:

- reading files;
- resolving files/specifiers;
- reporting test events;
- Playwright commands for browser tests;
- console forwarding through existing Volt console conventions.

### Browser tests

Keep PlaywrightEx optional and runtime-checked.

Dependency recommendation for Volt itself:

```elixir
{:playwright_ex, "~> 0.7", optional: true}
```

If a user enables browser tests without PlaywrightEx available, fail with an actionable error.

`Volt.Test.Playwright` should own:

- starting `PlaywrightEx.Supervisor` when needed;
- launching configured browsers;
- creating/closing browser contexts per ExUnit test;
- base URL handling;
- tracing/screenshots on failure in a later phase.

JS browser `page` should be a proxy object backed by `Beam.call` handlers, not a direct Playwright JS client. This keeps one browser control plane in Elixir/OTP and avoids adding a Node Playwright runtime for the test framework.

Start with a deliberately small browser API:

- `page.goto(url)`
- `page.click(selector)`
- `page.fill(selector, value)`
- `page.textContent(selector)`
- `page.locator(selector)`
- `expect(locator).toHaveText(text | regex)`
- `expect(locator).toBeVisible()`

Expand only when tests require more.

### ExUnit tags

Map Volt concepts to ExUnit tags:

- JS/TS tests: `@tag :js`
- browser tests: `@tag :browser`
- file path: `@tag file: path`
- framework or profile: `@tag profile: profile`

In generated bridges:

```elixir
@tag :js
@tag file: "assets/js/app.test.ts"
test "assets/js/app.test.ts" do
  assert_js_file!("assets/js/app.test.ts", @tag)
end
```

Browser tests should default to `async: false` unless Playwright lifecycle proves safe for concurrency.

## Failure output

JS assertion failures should be rendered as ExUnit failures, not only printed logs.

Example target output:

```text
1) test assets/js/math.test.ts (Volt.Generated.MathTest)
   assets/js/math.test.ts:4
   add › adds numbers

   Expected 3 to be 4

   expected: 4
        got: 3

   stacktrace:
     assets/js/math.test.ts:4:18
```

Browser failures should include page action context:

```text
homepage › shows welcome text

Expected locator("h1") to have text "Welcome"
Actual: "Loading..."
URL: http://localhost:4002/
```

## Phased implementation

### Phase 1: JS/TS unit-test MVP

- Add config/discovery.
- Add `Volt.Test.ExUnit.install/1` for `test/test_helper.exs`.
- Add the `priv/ts/test/core.ts` entry and focused runtime modules with `describe`, `test`, hooks, and core `expect` matchers. Implemented and dogfooded by `test/volt/test/fixtures/core_api.test.ts`.
- Run one ExUnit test per JS/TS file. Initial implementation is in place via generated bridge modules.
- Support async tests/promises.
- Add tests for pass/fail/async/hook behavior.
- Add a guide section.

### Phase 2: Better ExUnit integration

- Optional collection pass.
- Generate one ExUnit test per collected JS `test(...)`.
- Map tags and focused/skipped tests.
- Improve stack traces and source locations.

### Phase 3: Browser support

- Make PlaywrightEx an optional runtime dependency.
- Add `Volt.Test.BrowserCase`.
- Add JS `volt:test/browser` proxy API.
- Add browser test tags and lifecycle.
- Add screenshots/traces on failure.

### Phase 4: Watch mode

- Build on `Volt.Watcher` patterns.
- Re-run impacted JS tests on asset changes.
- Keep ExUnit-compatible non-watch mode as the stable CI path.

## Open questions

- Should generated ExUnit bridge modules stay in memory, or should Volt optionally materialize them for editor/source navigation?
- How much of Vitest’s `expect` surface should be included before recommending custom matchers?
- Should JS browser tests require an app server/base URL to be configured, or should Volt optionally start an endpoint under test?
- How should snapshots be represented: JS-style `__snapshots__` files, ExUnit-style assertions, or both?

## Recommendation

Implement Phase 1 first with one ExUnit test per JS/TS file. It is the most Volt-idiomatic low-risk slice because it keeps ExUnit in charge, uses Volt’s existing QuickBEAM runtime, avoids Node/Vitest, and leaves room for a richer collection-first runner later.
