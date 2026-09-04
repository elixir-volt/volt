defmodule Volt.Watcher.PathTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "normalizes filesystem aliases to a configured root", %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "root")
    alias_path = Path.join(tmp_dir, "alias")
    File.mkdir_p!(root)
    File.ln_s!(root, alias_path)

    assert Volt.Watcher.Path.normalize_from_roots(Path.join(alias_path, "app.js"), [root]) ==
             Path.join(root, "app.js")
  end

  test "preserves paths that do not belong to a configured root" do
    assert Volt.Watcher.Path.normalize_from_roots("/outside/app.js", ["/site/assets"]) ==
             "/outside/app.js"
  end
end
