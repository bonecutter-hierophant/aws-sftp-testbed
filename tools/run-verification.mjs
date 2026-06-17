#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const defaultGateSettleMs = process.platform === "win32" ? 750 : 0;
const gateSettleMs = Number.parseInt(process.env.VERIFY_GATE_SETTLE_MS ?? String(defaultGateSettleMs), 10);

const gateDefinitions = new Map([
  ["structure", ["node", ["tools/check-structure.mjs"]]],
  ["public-sanitization", ["node", ["tools/check-public-sanitization.mjs"]]],
  ["shell-static", ["node", ["tools/check-shell-static.mjs"]]],
  ["docs", ["node", ["tools/check-docs-whitespace.mjs"]]]
]);

const presets = new Map([
  ["docs", ["public-sanitization", "docs"]],
  ["safe", ["structure", "public-sanitization", "shell-static", "docs"]],
  ["review", ["structure", "public-sanitization", "shell-static", "docs"]]
]);

const recommendationRules = [
  [/^README\.md$/, ["public-sanitization", "docs"]],
  [/^AGENTS\.md$/, ["public-sanitization", "docs"]],
  [/^\.gitignore$/, ["structure", "public-sanitization", "docs"]],
  [/^package(-lock)?\.json$/, ["structure", "public-sanitization", "docs"]],
  [/^docs\//, ["public-sanitization", "docs"]],
  [/^infra\//, ["structure", "public-sanitization", "docs"]],
  [/^scripts\//, ["structure", "public-sanitization", "shell-static", "docs"]],
  [/^tools\//, ["structure", "public-sanitization", "shell-static", "docs"]]
];

const args = process.argv.slice(2);
const options = parseArgs(args);

if (options.help) {
  printHelp();
  process.exit(0);
}

if (options.list) {
  printList();
  process.exit(0);
}

if (options.recommend) {
  const result = recommend(options);
  printRecommendation(result);
  if (options.runRecommended) {
    runGates(result.gates);
  }
  process.exit(0);
}

const gates = resolveRequestedGates(options);
runGates(gates);

function parseArgs(values) {
  const parsed = {
    gates: null,
    preset: null,
    paths: [],
    dirty: false,
    recommend: false,
    runRecommended: false,
    list: false,
    help: false
  };

  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];

    if (value === "--help" || value === "-h") {
      parsed.help = true;
      continue;
    }

    if (value === "--list" || value === "list") {
      parsed.list = true;
      continue;
    }

    if (value === "--recommend") {
      parsed.recommend = true;
      continue;
    }

    if (value === "--dirty" || value === "dirty") {
      parsed.dirty = true;
      continue;
    }

    if (value === "--run") {
      parsed.runRecommended = true;
      continue;
    }

    if (value === "--gates") {
      parsed.gates = values[index + 1] ?? "";
      index += 1;
      continue;
    }

    if (value.startsWith("--gates=")) {
      parsed.gates = value.slice("--gates=".length);
      continue;
    }

    if (value === "--preset") {
      parsed.preset = values[index + 1] ?? "";
      index += 1;
      continue;
    }

    if (value.startsWith("--preset=")) {
      parsed.preset = value.slice("--preset=".length);
      continue;
    }

    if (value.startsWith("preset:")) {
      parsed.preset = value.slice("preset:".length);
      continue;
    }

    if (value === "--paths") {
      parsed.paths.push(...splitPathList(values[index + 1] ?? ""));
      index += 1;
      continue;
    }

    if (value.startsWith("--paths=")) {
      parsed.paths.push(...splitPathList(value.slice("--paths=".length)));
      continue;
    }

    if (value.startsWith("paths:")) {
      parsed.paths.push(...splitPathList(value.slice("paths:".length)));
      continue;
    }

    if (parsed.gates === null) {
      parsed.gates = value;
      continue;
    }

    parsed.gates = `${parsed.gates} ${value}`;
  }

  return parsed;
}

function resolveRequestedGates(options) {
  if (options.preset !== null) {
    const preset = presets.get(options.preset);

    if (preset === undefined) {
      fail(`Unknown verification preset "${options.preset}". Run with --list to see available presets.`);
    }

    return preset;
  }

  const gates = splitGateList(options.gates ?? "");

  if (gates.length === 0) {
    fail("No gates provided. Use --gates <list>, --preset <name>, --recommend, or --list.");
  }

  return gates;
}

function runGates(gates) {
  const uniqueGates = unique(gates);

  for (const gate of uniqueGates) {
    if (!gateDefinitions.has(gate)) {
      fail(`Unknown verification gate "${gate}". Run with --list to see available gates.`);
    }
  }

  console.log(`Running ${uniqueGates.length} verification gate${uniqueGates.length === 1 ? "" : "s"}: ${uniqueGates.join(", ")}`);

  for (const [index, gate] of uniqueGates.entries()) {
    const [command, commandArgs] = gateDefinitions.get(gate);
    console.log("");
    console.log(`[${index + 1}/${uniqueGates.length}] ${gate}`);
    console.log(`> ${formatCommand(command, commandArgs)}`);

    const result = spawnSync(resolveCommand(command), commandArgs, {
      cwd: repoRoot,
      stdio: "inherit",
      shell: shouldUseShell(command)
    });

    if (result.error !== undefined) {
      console.error(`Gate "${gate}" failed to start: ${result.error.message}`);
      process.exit(1);
    }

    if (result.status !== 0) {
      console.error(`Gate "${gate}" failed with exit code ${result.status}.`);
      process.exit(result.status ?? 1);
    }

    if (gateSettleMs > 0 && index < uniqueGates.length - 1) {
      sleep(gateSettleMs);
    }
  }

  console.log("");
  console.log("Verification gates passed.");
}

function recommend(options) {
  const inputPaths = unique([
    ...options.paths.map(normalizePath),
    ...(options.dirty ? readDirtyPaths() : [])
  ]).filter(Boolean);

  if (inputPaths.length === 0) {
    return {
      paths: [],
      gates: ["public-sanitization", "docs"],
      warnings: ["No paths were provided or detected; using docs as the minimal recommendation."]
    };
  }

  const gates = [];
  const warnings = [];

  for (const filePath of inputPaths) {
    const matches = recommendationRules.filter(([pattern]) => pattern.test(filePath));

    if (matches.length === 0) {
      gates.push(...presets.get("review"));
      warnings.push(`${filePath}: no mapping found; recommending full review gates because ownership is unclear.`);
      continue;
    }

    for (const [, mappedGates] of matches) {
      gates.push(...mappedGates);
    }
  }

  return {
    paths: inputPaths,
    gates: unique(gates),
    warnings
  };
}

function readDirtyPaths() {
  const outputs = [
    runGit(["diff", "--name-only", "HEAD"]),
    runGit(["diff", "--cached", "--name-only"]),
    runGit(["ls-files", "--others", "--exclude-standard"])
  ];

  return unique(
    outputs
      .flatMap((output) => output.split(/\r?\n/))
      .map((value) => normalizePath(value.trim()))
      .filter(Boolean)
  );
}

function runGit(args) {
  const result = spawnSync("git", args, {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    shell: shouldUseShell("git")
  });

  if (result.error !== undefined || result.status !== 0) {
    const reason = result.error?.message ?? result.stderr.trim() ?? `exit ${result.status}`;
    fail(`Unable to read git ${args.join(" ")}: ${reason}`);
  }

  return result.stdout.trim();
}

function printRecommendation(result) {
  console.log("Verification recommendation");
  console.log("");
  console.log("Paths:");
  if (result.paths.length === 0) {
    console.log("- <none>");
  } else {
    result.paths.forEach((filePath) => console.log(`- ${filePath}`));
  }

  console.log("");
  console.log("Recommended gates:");
  result.gates.forEach((gate) => console.log(`- ${gate}`));

  console.log("");
  console.log(`Command: npm run verify:scoped ${result.gates.join(",")}`);

  if (result.warnings.length > 0) {
    console.log("");
    console.log("Warnings:");
    result.warnings.forEach((warning) => console.log(`- ${warning}`));
  }
}

function printList() {
  console.log("Verification gates:");
  for (const [gate, [command, commandArgs]] of gateDefinitions.entries()) {
    console.log(`- ${gate}: ${formatCommand(command, commandArgs)}`);
  }

  console.log("");
  console.log("Presets:");
  for (const [preset, gates] of presets.entries()) {
    console.log(`- ${preset}: ${gates.join(", ")}`);
  }
}

function printHelp() {
  console.log(`Usage:
  node tools/run-verification.mjs structure,docs
  node tools/run-verification.mjs --gates structure,docs
  node tools/run-verification.mjs preset:review
  node tools/run-verification.mjs --preset review
  node tools/run-verification.mjs --recommend --dirty
  node tools/run-verification.mjs --recommend paths:scripts/deploy.sh
  node tools/run-verification.mjs --list

Options:
  --gates <list>      Comma-separated verification gates to run sequentially.
  --preset <name>     Named gate set to run sequentially.
  --recommend         Print recommended gates instead of running explicit gates.
  --dirty             Recommend from staged, unstaged, and untracked Git paths.
  --paths <list>      Recommend from comma-separated paths.
  --run               With --recommend, run the recommended gates after printing them.
  --list              Print known gates and presets.
`);
}

function splitGateList(value) {
  return String(value)
    .split(/[,\s]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function splitPathList(value) {
  return String(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function normalizePath(value) {
  return value.replaceAll("\\", "/").replace(/^\.\//, "");
}

function unique(values) {
  return [...new Set(values)];
}

function formatCommand(command, args) {
  return [command, ...args].join(" ");
}

function resolveCommand(command) {
  return command;
}

function shouldUseShell(command) {
  return process.platform === "win32" && (command === "npm" || command === "git");
}

function sleep(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
