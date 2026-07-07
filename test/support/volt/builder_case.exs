defmodule Volt.TestSupport.BuilderCase do
  use ExUnit.CaseTemplate

  defmodule JSLoaderPlugin do
    @behaviour Volt.Plugin
    def name, do: "js-loader"
    def resolve(_, _), do: nil

    def load(path) do
      if String.ends_with?(path, ".custom") and File.regular?(path) do
        {:ok, File.read!(path), "application/javascript"}
      end
    end
  end

  defmodule EmbeddedBoxPlugin do
    @behaviour Volt.Plugin

    @impl true
    def name, do: "embedded-box"

    @impl true
    def extensions(kind) when kind in [:compile, :resolve, :watch, :scan], do: [".box"]
    def extensions(_kind), do: []

    @impl true
    def compile(path, source, _opts) do
      if Path.extname(path) == ".box" do
        modules =
          path |> embedded_modules(source, []) |> Volt.Plugin.EmbeddedModule.normalize_all()

        imports =
          modules
          |> Enum.map(&Volt.Plugin.EmbeddedModule.specifier(path, &1))
          |> Enum.map_join("\n", &~s(import #{inspect(&1)};))

        {:ok, %Volt.Pipeline.Result{code: imports <> "\nexport const box = true;"}}
      end
    end

    @impl true
    def embedded_modules(path, source, _opts) do
      if Path.extname(path) == ".box" do
        [
          %Volt.Plugin.EmbeddedModule{
            type: :style,
            extension: ".css",
            source: between(source, "<style>", "</style>")
          },
          %Volt.Plugin.EmbeddedModule{
            type: :script,
            extension: ".ts",
            source: between(source, "<script>", "</script>")
          }
        ]
      end
    end

    defp between(source, open, close) do
      with [_before, rest] <- String.split(source, open, parts: 2),
           [content, _after] <- String.split(rest, close, parts: 2) do
        content
      else
        _ -> ""
      end
    end
  end

  defmodule VirtualModPlugin do
    @behaviour Volt.Plugin
    def name, do: "virtual-mod"
    def resolve("my-virtual", _), do: {:ok, "virtual:my-virtual"}
    def resolve("virtual-entry", _), do: {:ok, "virtual:entry"}
    def resolve("virtual:site/entry-a", _), do: {:ok, "virtual:site/entry-a"}
    def resolve("virtual:site/entry-b", _), do: {:ok, "virtual:site/entry-b"}
    def resolve("virtual:site/style-entry", _), do: {:ok, "virtual:site/style-entry"}
    def resolve("virtual:plain", _), do: {:ok, "virtual:plain"}

    def resolve("./style.css", "virtual:site/style-entry"),
      do: {:ok, Path.join([System.tmp_dir!(), "volt-builder-test", "src/style.css"])}

    def resolve(_, _), do: nil
    def load("virtual:my-virtual"), do: {:ok, "export default 99;"}

    def load("virtual:entry"), do: {:ok, "import val from 'my-virtual'; console.log(val);"}

    def load("virtual:site/entry-a"), do: {:ok, "console.log('entry a');"}

    def load("virtual:site/entry-b"), do: {:ok, "console.log('entry b');"}

    def load("virtual:site/style-entry"),
      do: {:ok, "import './style.css'; console.log('with css');"}

    def load("virtual:plain"), do: {:ok, "export default 123;"}

    def load(_), do: nil
  end

  using do
    quote do
      use ExUnit.Case, async: false

      alias Volt.TestSupport.BuilderCase.{EmbeddedBoxPlugin, JSLoaderPlugin, VirtualModPlugin}

      @fixture_dir Path.join(System.tmp_dir!(), "volt-builder-test")
      @outdir Path.join(@fixture_dir, "dist")

      setup do
        File.mkdir_p!(Path.join(@fixture_dir, "src"))

        File.write!(Path.join(@fixture_dir, "src/utils.ts"), """
        export function greet(name: string): string {
          return `Hello, ${name}!`
        }
        """)

        File.write!(Path.join(@fixture_dir, "src/app.ts"), """
        import { greet } from './utils'
        console.log(greet('world'))
        """)

        on_exit(fn ->
          File.rm_rf!(@fixture_dir)
          File.rm_rf!(@outdir)
        end)

        :ok
      end
    end
  end
end
