ExUnit.start(exclude: [:integration])

Volt.Test.ExUnit.install(root: "priv/ts", include: ["test/core.test.ts"])
