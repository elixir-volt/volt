# Changelog

## 0.2.0

- Fix nested export conditions in package.json resolution (Vue, Reka UI)
- Plugin system for custom file types and transforms
- CSS Modules via LightningCSS
- Static asset imports (images, fonts → URL references)
- JSON imports
- Environment variable replacement (`import.meta.env.*`)
- Import aliases (e.g. `%{"@" => "assets/src"}`)
- Multi-entry builds
- Bump deps: oxc ~> 0.5.1 (circular dep support), quickbeam ~> 0.7.1

## 0.1.0

- Initial release
- JS/TS bundling via OXC
- Vue SFC compilation via Vize
- Tailwind CSS v4 via Oxide + QuickBEAM
- Dev server with HMR and file watcher
- Production builds with content-hashed output and manifests
- `mix volt.build` and `mix volt.dev` tasks
