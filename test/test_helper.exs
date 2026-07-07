Path.wildcard(Path.expand("support/**/*.exs", __DIR__))
|> Enum.sort()
|> Enum.each(&Code.require_file/1)

ExUnit.start(exclude: [:integration])

Volt.Test.ExUnit.install(root: "test/volt/test/fixtures", include: ["core_api.test.ts"])
