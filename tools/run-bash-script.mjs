#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const repoRoot = dirname(fileURLToPath(new URL("../package.json", import.meta.url)));
const [scriptPath, ...scriptArgs] = process.argv.slice(2);

if (scriptPath === undefined) {
  console.error("Usage: node tools/run-bash-script.mjs <script> [args...]");
  process.exit(1);
}

const bashPath = resolveBashPath();
const result = spawnSync(bashPath, [scriptPath, ...scriptArgs], {
  cwd: repoRoot,
  stdio: "inherit",
  shell: false
});

if (result.error !== undefined) {
  console.error(`Failed to run ${scriptPath}: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);

function resolveBashPath() {
  if (process.platform !== "win32") {
    return "bash";
  }

  const gitBash = "C:\\Program Files\\Git\\bin\\bash.exe";
  if (existsSync(gitBash)) {
    return gitBash;
  }

  return "bash";
}
