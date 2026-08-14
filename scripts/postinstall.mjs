import { chmodSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

if (process.platform !== "win32") {
  const packageRoot = "node_modules/@oxlint-tsgolint";

  for (const directory of readdirSync(packageRoot)) {
    const executable = join(packageRoot, directory, "tsgolint");

    if (existsSync(executable)) {
      chmodSync(executable, 0o755);
    }
  }
}
