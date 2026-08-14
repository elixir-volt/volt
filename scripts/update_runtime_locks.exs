Logger.configure(level: :warning)

alias Volt.JS.Runtime.Installer

sets = [
  Volt.Plugin.Svelte.runtime_package_set(),
  Volt.Plugin.Solid.runtime_package_set(),
  Volt.Tailwind.Loader.runtime_package_set()
]

{opts, args} = OptionParser.parse!(System.argv(), strict: [only: :keep])

if args != [] do
  raise ArgumentError, "unexpected arguments: #{Enum.join(args, " ")}"
end

requested = opts |> Keyword.get_values(:only) |> MapSet.new()

selected =
  if MapSet.size(requested) == 0 do
    sets
  else
    Enum.filter(sets, &MapSet.member?(requested, Atom.to_string(&1.name)))
  end

found = selected |> Enum.map(&Atom.to_string(&1.name)) |> MapSet.new()
missing = MapSet.difference(requested, found)

if MapSet.size(missing) > 0 do
  raise ArgumentError,
        "unknown runtime package sets: #{missing |> Enum.sort() |> Enum.join(", ")}"
end

tmp_dir =
  Path.join(
    System.tmp_dir!(),
    "volt-runtime-locks-#{System.unique_integer([:positive])}"
  )

File.mkdir_p!(tmp_dir)

try do
  Enum.each(selected, fn set ->
    install =
      Installer.install!(set.packages,
        install_dir: Path.join(tmp_dir, Atom.to_string(set.name)),
        force: true
      )

    generated = Path.join(install.install_dir, "npm.lock")
    target = Path.expand("../priv/npm/#{set.name}.lock", __DIR__)
    File.mkdir_p!(Path.dirname(target))
    File.cp!(generated, target)

    digest =
      target |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    Mix.shell().info("Updated #{Path.relative_to_cwd(target)} (sha256: #{digest})")
  end)
after
  File.rm_rf!(tmp_dir)
end
