[
  plugins: [Volt.Formatter],
  import_deps: [:phoenix],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "assets/**/*.{js,ts,jsx,tsx}"
  ]
]
