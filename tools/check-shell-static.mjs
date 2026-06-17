#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const scriptsRoot = join(repoRoot, "scripts");
const failures = [];

for (const filePath of readShellFiles()) {
  const content = readFileSync(join(repoRoot, filePath), "utf8");

  if (!content.startsWith("#!/usr/bin/env bash\n")) {
    failures.push(`${filePath} must start with a bash shebang`);
  }

  if (!content.includes("set -euo pipefail")) {
    failures.push(`${filePath} must enable set -euo pipefail`);
  }

  if (filePath.startsWith("scripts/") && filePath !== "scripts/lib/common.sh" && !content.includes("source \"$script_dir/lib/common.sh\"")) {
    failures.push(`${filePath} must source scripts/lib/common.sh`);
  }
}

if (failures.length > 0) {
  console.error("Shell static check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}

function readShellFiles() {
  const discovered = [];
  walk(scriptsRoot, discovered);
  return discovered;
}

function walk(directory, discovered) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = join(directory, entry.name);
    const filePath = normalizePath(relative(repoRoot, absolutePath));

    if (entry.isDirectory()) {
      walk(absolutePath, discovered);
      continue;
    }

    if (entry.isFile() && filePath.endsWith(".sh")) {
      discovered.push(filePath);
    }
  }
}

function normalizePath(value) {
  return value.replaceAll("\\", "/").replace(/^\.\//, "");
}
