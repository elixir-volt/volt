defmodule Volt.TestSupport.DevServerCase do
  use ExUnit.CaseTemplate

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

  defmodule VirtualPlugin do
    @behaviour Volt.Plugin

    def name, do: "virtual"

    def resolve("virtual:routes", _importer), do: {:ok, "virtual:routes"}
    def resolve("virtual:client", _importer), do: {:ok, "virtual:client"}
    def resolve("virtual:plain", _importer), do: {:ok, "virtual:plain"}
    def resolve(_specifier, _importer), do: nil

    def load("virtual:routes"), do: {:ok, "export default [{ path: '/' }];"}

    def load("virtual:client") do
      {:ok, "import routes from 'virtual:routes'; export default routes;"}
    end

    def load("virtual:plain"), do: {:ok, "export default 123;"}

    def load(_id), do: nil
  end

  using do
    quote do
      use ExUnit.Case, async: false
      import Plug.Conn
      import Plug.Test

      alias Volt.TestSupport.DevServerCase.{EmbeddedBoxPlugin, VirtualPlugin}

      @fixture_dir Path.expand("volt-dev-server-test", System.tmp_dir!())

      setup do
        File.mkdir_p!(Path.join(@fixture_dir, "src"))
        File.write!(Path.join(@fixture_dir, "src/app.ts"), "const x: number = 42")
        File.write!(Path.join(@fixture_dir, "src/style.css"), ".foo { color: red }")

        File.write!(Path.join(@fixture_dir, "src/App.vue"), """
        <template><div>{{ msg }}</div></template>
        <script setup>const msg = 'hi'</script>
        """)

        Volt.Cache.clear()
        Volt.HMR.StyleGraph.clear()
        Volt.HMR.ModuleGraph.clear()

        on_exit(fn -> File.rm_rf!(@fixture_dir) end)
        :ok
      end

      defp call_dev_server(path, opts \\ []) do
        init_opts =
          Keyword.merge(
            [root: Path.join(@fixture_dir, "src"), prefix: "/assets"],
            opts
          )

        opts = Volt.DevServer.init(init_opts)
        conn(:get, path) |> Volt.DevServer.call(opts)
      end

      defp flush_hmr_messages do
        receive do
          {:volt_hmr, _type, _payload} -> flush_hmr_messages()
        after
          0 -> :ok
        end
      end
    end
  end
end
