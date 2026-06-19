#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const failures = [];

const bootstrapScripts = [
  {
    file: "scripts/bootstrap/inspect.sh",
    mutatesAws: false
  },
  {
    file: "scripts/bootstrap/create-account.sh",
    mutatesAws: true,
    approvalFlag: "--approve-create-account",
    requiredAwsCalls: ["organizations create-account"]
  },
  {
    file: "scripts/bootstrap/ensure-permission-set.sh",
    mutatesAws: true,
    approvalFlag: "--approve-permission-set",
    requiredAwsCalls: ["sso-admin put-inline-policy-to-permission-set"]
  },
  {
    file: "scripts/bootstrap/assign-permission-set.sh",
    mutatesAws: true,
    approvalFlag: "--approve-assignment",
    requiredAwsCalls: ["sso-admin create-account-assignment"]
  },
  {
    file: "scripts/bootstrap/configure-routine-profile.sh",
    mutatesAws: false,
    approvalFlag: "--approve-local-profile"
  }
];

for (const script of bootstrapScripts) {
  const content = readFileSync(join(repoRoot, script.file), "utf8");

  requireIn(script, content, "require_bootstrap_selected", "must require explicit --bootstrap lane");
  requireIn(script, content, "Do not commit", "must warn against committing live output");

  if (script.approvalFlag !== undefined) {
    requireIn(script, content, script.approvalFlag, `must document ${script.approvalFlag}`);
  }

  if (script.mutatesAws) {
    requireIn(script, content, "Refusing", "must refuse mutation without explicit approval");
    requireIn(script, content, script.approvalFlag, `must require ${script.approvalFlag} before mutation`);
  }

  for (const awsCall of script.requiredAwsCalls ?? []) {
    requireIn(script, content, awsCall, `must contain expected AWS call: ${awsCall}`);
  }
}

if (failures.length > 0) {
  console.error("Bootstrap static check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}

function requireIn(script, content, needle, message) {
  if (!content.includes(needle)) {
    failures.push(`${script.file}: ${message}`);
  }
}
