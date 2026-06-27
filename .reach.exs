file_mutation = ["File.write!", "File.rm", "File.rm_rf!"]
app_config = [
  "Application.get_env",
  "Application.get_all_env",
  "Application.fetch_env",
  "Application.put_env",
  "Application.delete_env"
]
compat_json = [":json.*"]
unsafe_runtime_encoding = ["Jason.encode!"]
unstable_hashing = [":erlang.phash2"]
builder_runtime = ["Volt.DevServer.*", "Volt.Watcher.*", "Volt.HMR.*"]
asset_runtime = ["Volt.Assets.*", "Volt.Builder.*", "Volt.DevServer.*", "Volt.JS.*"]
ast_side_effects = app_config ++ file_mutation ++ ["System.cmd", "QuickBEAM.*"] ++ builder_runtime

adapter = [
  "Mix.Tasks.Volt.*",
  "Volt",
  "Volt.Formatter"
]

orchestrator = [
  "Volt.Builder",
  "Volt.Builder.Collector",
  "Volt.Builder.Externals",
  "Volt.Builder.Output",
  "Volt.Builder.Rewriter",
  "Volt.DevServer",
  "Volt.HMR",
  "Volt.JS.Vendor",
  "Volt.Pipeline",
  "Volt.Tailwind",
  "Volt.Watcher"
]

model = [
  "Volt.Builder.BuildContext",
  "Volt.Builder.Collector.State",
  "Volt.Builder.Context",
  "Volt.Builder.Dependencies",
  "Volt.Builder.ManifestEntry",
  "Volt.Builder.OutputContext",
  "Volt.Builder.OutputFile",
  "Volt.Builder.Result",
  "Volt.ChunkGraph.Chunk",
  "Volt.Config",
  "Volt.Config.*",
  "Volt.DevServer.CacheEntry",
  "Volt.DevServer.Config",
  "Volt.HMR.Message",
  "Volt.JS.ImportExtractor.Result",
  "Volt.JS.PrebundleEntry.Export",
  "Volt.JS.PrebundleEntry.Import",
  "Volt.JS.Runtime.Installer.Metadata",
  "Volt.JS.TSConfig",
  "Volt.MIME",
  "Volt.Paths",
  "Volt.Pipeline.Result.Hashes"
]

logic = [
  "Volt.Assets",
  "Volt.Assets.Query",
  "Volt.Builder.Resolver",
  "Volt.ChunkGraph",
  "Volt.CSS.AST",
  "Volt.CSS.AssetURLRewriter",
  "Volt.CSS.Dependencies",
  "Volt.CSS.Modules",
  "Volt.Env",
  "Volt.Format",
  "Volt.HTMLEntry",
  "Volt.JS.AST",
  "Volt.JS.Check",
  "Volt.JS.Extensions",
  "Volt.JS.Format",
  "Volt.JS.Helpers",
  "Volt.JS.ImportExtractor",
  "Volt.JS.Patch",
  "Volt.JS.PrebundleEntry",
  "Volt.JS.Resolution",
  "Volt.JS.Resolver",
  "Volt.JS.Transforms.AssetURLs",
  "Volt.JS.Transforms.DynamicImports",
  "Volt.JS.Transforms.DynamicImports.Replacement",
  "Volt.JS.Transforms.GlobImports",
  "Volt.JS.Transforms.GlobImports.Call",
  "Volt.JS.Transforms.GlobImports.File",
  "Volt.JS.Transforms.ImportMetaEnv",
  "Volt.JS.Transforms.Imports",
  "Volt.JS.Transforms.Specifiers",
  "Volt.JS.Transforms.Workers",
  "Volt.Path",
  "Volt.Plugin.EmbeddedModule",
  "Volt.Plugin.EmbeddedModule.ID",
  "Volt.Pipeline.Result",
  "Volt.PluginRunner",
  "Volt.Preload",
  "Volt.PublicDir",
  "Volt.Tailwind.Resolver",
  "Volt.URL"
]

infrastructure = [
  "Volt.Application",
  "Volt.Builder.Writer",
  "Volt.Cache",
  "Volt.Dev.ConsoleForwarder",
  "Volt.ETS",
  "Volt.HMR.Boundary",
  "Volt.HMR.GlobGraph",
  "Volt.HMR.ImportGraph",
  "Volt.HMR.ModuleGraph",
  "Volt.HMR.ModuleGraph.Node",
  "Volt.HMR.Socket",
  "Volt.HMR.StyleDependencies",
  "Volt.HMR.StyleGraph",
  "Volt.JS.Asset",
  "Volt.Priv",
  "Volt.JS.Runtime",
  "Volt.JS.Runtime.Bundler",
  "Volt.JS.Runtime.Entry",
  "Volt.JS.Runtime.Error",
  "Volt.JS.Runtime.Installer",
  "Volt.Tailwind.Loader"
]

plugin = [
  "Volt.Plugin",
  "Volt.Plugin.Helpers",
  "Volt.Plugin.React",
  "Volt.Plugin.Solid",
  "Volt.Plugin.Solid.CompilerOptions",
  "Volt.Plugin.Solid.CompilerOptions.SolidOptions",
  "Volt.Plugin.Svelte",
  "Volt.Plugin.Svelte.CompilerOptions",
  "Volt.Plugin.Vue"
]

model_must_not_depend_on = [:adapter, :orchestrator, :infrastructure]
logic_must_not_depend_on = [:adapter, :orchestrator, :infrastructure]

[
  layers: [
    adapter: adapter,
    orchestrator: orchestrator,
    model: model,
    logic: logic,
    infrastructure: infrastructure,
    plugin: plugin
  ],
  checks: [
    layer_coverage: [
      require_all_modules: true,
      forbid_multiple_matches: true,
      ignore: ["Jason.Encoder.*"]
    ]
  ],
  deps: [
    forbidden:
      Enum.map(model_must_not_depend_on, &{:model, &1}) ++
        Enum.map(logic_must_not_depend_on, &{:logic, &1}) ++
        [
          {:infrastructure, :adapter},
          {:plugin, :adapter}
        ]
  ],
  source: [
    forbidden_modules: [
      "Volt.Builder.BundleResult",
      "Volt.DepGraph",
      "Volt.HMR.Client",
      "Volt.JS.PackageResolver",
      "Volt.JS.VueImports",
      "Volt.Mix"
    ]
  ],
  calls: [
    forbidden: [
      {"Volt.URL", app_config ++ asset_runtime},
      {"Volt.Path", app_config ++ asset_runtime},
      {"Volt.JS.AST", ast_side_effects},
      {"Volt.CSS.AST", ast_side_effects},
      {"Volt.JS.Transforms.*", ["QuickBEAM.*", "System.cmd"] ++ file_mutation},
      {"Volt.Builder*", builder_runtime},
      {"Volt.HMR.*Graph",
       ["Volt.HMR.Socket.*", "Registry.dispatch", "WebSock.*", "WebSockAdapter.*"] ++
         file_mutation ++ ["System.cmd"]},
      {"Volt.Plugin",
       [
         "Volt.Plugin.React.*",
         "Volt.Plugin.Solid.*",
         "Volt.Plugin.Svelte.*",
         "Volt.Plugin.Vue.*"
       ]},
      {"Volt.*", compat_json, except: ["Volt.Plugin.*"]},
      {"Volt.HMR.Socket", unsafe_runtime_encoding},
      {"Volt.Plugin.*", unstable_hashing},
      {"Mix.Tasks.Volt.Js.Check", ["OXC.Format.run!", "OXC.Lint.run!"]}
    ]
  ],
  effects: [
    allowed: [
      {"Volt.URL", [:pure, :unknown, :exception]},
      {"Volt.Path", [:pure, :unknown, :exception]},
      {"Volt.JS.AST", [:pure, :unknown, :exception, :nif]},
      {"Volt.CSS.AST", [:pure, :unknown, :exception, :nif]}
    ]
  ],
  smells: [
    strict: true
  ]
]
