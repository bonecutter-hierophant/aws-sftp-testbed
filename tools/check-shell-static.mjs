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

  const sourcesCommonHelper = content.includes("source \"$script_dir/lib/common.sh\"")
    || content.includes("source \"$script_dir/../lib/common.sh\"")
    || content.includes("source \"$script_dir/../../scripts/lib/common.sh\"");
  if (filePath.startsWith("scripts/") && filePath !== "scripts/lib/common.sh" && !sourcesCommonHelper) {
    failures.push(`${filePath} must source scripts/lib/common.sh`);
  }
}

requireScriptText("scripts/deploy.sh", "require_allowed_cidr", "deploy must require an explicit allowed CIDR");
requireScriptText("scripts/deploy.sh", "AllowPublicCidr=$allow_public_cidr", "deploy must pass the explicit public CIDR override to CloudFormation");
requireScriptText("scripts/deploy.sh", "CAPABILITY_NAMED_IAM", "deploy must acknowledge named IAM resources for opt-in diagnostics");
requireScriptText("scripts/destroy.sh", "--approve-destroy", "destroy must require explicit approval");
requireScriptText("scripts/destroy.sh", "aws ssm delete-parameter", "destroy must delete the runtime connection parameter by default");
requireScriptText("scripts/enable-diagnostics.sh", "CAPABILITY_NAMED_IAM", "diagnostics enable must acknowledge named IAM resources");
requireScriptText("scripts/disable-diagnostics.sh", "EnableSsmDiagnostics,ParameterValue=false", "diagnostics disable must remove the helper profile");
requireScriptText("scripts/diagnose-source-ip.sh", "AWS-RunShellScript", "source IP diagnostics must use SSM Run Command");
requireScriptText("scripts/update-parameter.sh", "--type SecureString", "connection publication must use SecureString");

if (failures.length > 0) {
  console.error("Shell static check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}

function requireScriptText(filePath, needle, message) {
  const content = readFileSync(join(repoRoot, filePath), "utf8");

  if (!content.includes(needle)) {
    failures.push(`${filePath}: ${message}`);
  }
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
