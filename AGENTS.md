# Project Guidelines

- Match primary Elixir module namespaces to their source paths. Nested data modules, protocol implementations, conditional definitions, and established acronym spellings are deliberate exceptions.
- Mirror source paths and namespaces in unit tests. Keep cross-module scenarios under the owning subsystem or integration directory; do not invent a production module merely to match a scenario test.
- Keep Mix tasks in nested `lib/mix/tasks/` paths as `.ex`, tests as `_test.exs`, and shared support as `.ex` under `test/support/`, compiled only in the test environment. `lib/volt/test/` contains shipped framework APIs, not project test support.

- Prefer parser/AST-backed solutions over hand-rolled regular expressions for source code, markup, and structured formats. Use existing parsers such as OXC for JavaScript/TypeScript and Floki for HTML-like markup when available.
