defmodule Volt.JS.PackageTest do
  use ExUnit.Case, async: true

  describe "linked_dirs/1" do
    @tag :tmp_dir
    test "lists the real directories of packages linked from outside node_modules", %{
      tmp_dir: project
    } do
      node_modules = Path.join(project, "node_modules")
      linked = Path.join(project, "packages/client")
      scoped = Path.join(project, "packages/scoped")
      File.mkdir_p!(Path.join(node_modules, "installed"))
      File.mkdir_p!(Path.join(node_modules, "@scope"))
      File.mkdir_p!(linked)
      File.mkdir_p!(scoped)
      File.ln_s!("../packages/client", Path.join(node_modules, "client"))
      File.ln_s!("../../packages/scoped", Path.join(node_modules, "@scope/scoped"))
      # A link inside node_modules, as package managers make for workspaces'
      # hoisted copies, is not a linked package.
      File.ln_s!("./installed", Path.join(node_modules, "alias"))

      assert Enum.sort(Volt.JS.Package.linked_dirs(node_modules)) ==
               Enum.sort([Path.expand(linked), Path.expand(scoped)])
    end

    test "has nothing to list without node_modules" do
      assert Volt.JS.Package.linked_dirs(nil) == []
      assert Volt.JS.Package.linked_dirs("/nonexistent/node_modules") == []
    end
  end
end
