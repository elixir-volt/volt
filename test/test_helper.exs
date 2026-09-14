ExUnit.start(exclude: [:integration])

Volt.Test.ExUnit.install(root: "test/volt/test/fixtures", include: ["core_api.test.ts"])
