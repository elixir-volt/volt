defmodule Volt.Priv.VendorTest do
  use ExUnit.Case, async: true

  alias Volt.Priv.Vendor

  @moduletag :tmp_dir

  test "keeps the browser modules and declarations the sources reach", %{tmp_dir: tmp_dir} do
    sources = Path.join(tmp_dir, "priv/ts")
    node_modules = Path.join(tmp_dir, "install/node_modules")

    write!(sources, %{
      "app.ts" => """
      import { widget } from 'kit'
      import 'kit/extra.js'
      import { compile } from 'runtime-only'
      import { local } from './local'
      """,
      "local.ts" => "export const local = 1\n"
    })

    write!(node_modules, %{
      "kit/package.json" =>
        Jason.encode!(%{
          name: "kit",
          exports: %{
            "." => %{types: "./types/kit.d.ts", browser: "./kit.js", default: "./node/kit.js"},
            "./extra.js" => "./extra.js"
          }
        }),
      "kit/LICENSE" => "MIT",
      "kit/kit.js" => "import { helper } from './helper.js'\nexport const widget = helper\n",
      "kit/helper.js" => "export const helper = 1\n",
      "kit/node/kit.js" => "export const widget = 1\n",
      "kit/extra.js" => "export {}\n",
      "kit/extra.d.ts" => "export {}\n",
      "kit/unused.js" => "export {}\n",
      "kit/kit.js.map" => "{}",
      "kit/types/kit.d.ts" =>
        "import type { Policy } from 'policy/lib/index.js'\nexport declare const widget: Policy\n",
      "@types/policy/package.json" => Jason.encode!(%{name: "@types/policy"}),
      "@types/policy/lib/index.d.ts" => "export type Policy = string\n",
      "runtime-only/package.json" => Jason.encode!(%{name: "runtime-only", main: "index.js"}),
      "runtime-only/index.js" => "export const compile = 1\n"
    })

    assert Vendor.reachable(sources, %{"kit" => "1.0.0"}, node_modules) == [
             "@types/policy/lib/index.d.ts",
             "@types/policy/package.json",
             "kit/LICENSE",
             "kit/extra.d.ts",
             "kit/extra.js",
             "kit/helper.js",
             "kit/kit.js",
             "kit/package.json",
             "kit/types/kit.d.ts"
           ]
  end

  defp write!(root, files) do
    for {path, contents} <- files do
      path = Path.join(root, path)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
    end
  end
end
