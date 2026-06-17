#!/usr/bin/env node
import { existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const failures = [];

const requiredFiles = [
  "README.md",
  "AGENTS.md",
  ".gitignore",
  ".vscode/extensions.json",
  ".vscode/settings.json",
  ".vscode/tasks.json",
  "package.json",
  "docs/architecture/README.md",
  "docs/architecture/project-structure.md",
  "docs/architecture/testbed-lifecycle.puml",
  "docs/operations/README.md",
  "docs/operations/feature-development-workflow.md",
  "docs/operations/public-repository-sanitization.md",
  "docs/operations/aws-sftp-boundary.md",
  "docs/operations/aws-access-setup.md",
  "docs/operations/diagram-rendering.md",
  "docs/operations/sandbox-safe-verification.md",
  "docs/operations/scoped-verification-gates.md",
  "docs/proposals/mvp-tooling-roadmap.md",
  "infra/README.md",
  "infra/cloudformation/README.md",
  "infra/cloudformation/template.yaml",
  "scripts/README.md",
  "scripts/lib/README.md",
  "scripts/lib/common.sh",
  "scripts/deploy.sh",
  "scripts/start.sh",
  "scripts/stop.sh",
  "scripts/destroy.sh",
  "scripts/describe.sh",
  "scripts/update-secret.sh",
  "scripts/smoke-test.sh",
  "tools/README.md"
];

for (const filePath of requiredFiles) {
  const absolutePath = join(repoRoot, filePath);
  const stat = statSync(absolutePath, { throwIfNoEntry: false });

  if (stat === undefined || !stat.isFile()) {
    failures.push(`${filePath} is missing`);
  }
}

for (const directoryPath of [".vscode", "docs", "docs/proposals", "infra", "scripts", "scripts/lib", "tools"]) {
  if (!existsSync(join(repoRoot, directoryPath))) {
    failures.push(`${directoryPath}/ is missing`);
  }
}

if (failures.length > 0) {
  console.error("Structure check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}
