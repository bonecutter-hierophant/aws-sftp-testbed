#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const failures = [];
const gitIndexPath = join(repoRoot, ".git", "index");

const excludedPathPatterns = [
  /^\.git\//,
  /^\.local\//,
  /^\.tmp\//,
  /^node_modules\//,
  /^dist\//,
  /^build\//,
  /^coverage\//
];

const textExtensions = new Set(["", ".css", ".html", ".js", ".json", ".md", ".mjs", ".puml", ".sh", ".txt", ".yaml", ".yml"]);

const denyPatterns = [
  {
    name: "AWS access key",
    pattern: /\b(A3T[A-Z0-9]|AKIA|ASIA)[A-Z0-9]{16}\b/g
  },
  {
    name: "private key block",
    pattern: /-----BEGIN (RSA |DSA |EC |OPENSSH |PGP )?PRIVATE KEY-----/g
  },
  {
    name: "GitHub token",
    pattern: /\bgh[pousr]_[A-Za-z0-9_]{30,}\b/g
  },
  {
    name: "Slack token",
    pattern: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/g
  },
  {
    name: "Google API key",
    pattern: /\bAIza[0-9A-Za-z_-]{35}\b/g
  },
  {
    name: "Stripe secret key",
    pattern: /\bsk_(live|test)_[0-9A-Za-z]{20,}\b/g
  },
  {
    name: "local absolute Windows user path",
    pattern: /\bC:\\Users\\[A-Za-z0-9._-]+\\/g
  }
];

checkGitIndex();

for (const filePath of readRepoPaths()) {
  if (shouldSkip(filePath)) {
    continue;
  }

  const absolutePath = join(repoRoot, filePath);
  const stat = statSync(absolutePath, { throwIfNoEntry: false });

  if (stat === undefined || !stat.isFile() || !isTextFile(filePath)) {
    continue;
  }

  const content = readFileSync(absolutePath, "utf8");
  checkContent(filePath, content);
}

if (failures.length > 0) {
  console.error("Public repository sanitization check failed:");
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exitCode = 1;
}

function readRepoPaths() {
  const discovered = [];
  walk(repoRoot, discovered);
  return discovered;
}

function walk(directory, discovered) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = join(directory, entry.name);
    const filePath = normalizePath(relative(repoRoot, absolutePath));

    if (shouldSkip(filePath) || shouldSkip(`${filePath}/`)) {
      continue;
    }

    if (entry.isDirectory()) {
      walk(absolutePath, discovered);
      continue;
    }

    discovered.push(filePath);
  }
}

function checkContent(filePath, content) {
  for (const { name, pattern } of denyPatterns) {
    pattern.lastIndex = 0;

    let match = pattern.exec(content);
    while (match !== null) {
      const line = lineNumberForIndex(content, match.index);
      failures.push(`${filePath}:${line} matched ${name}`);
      match = pattern.exec(content);
    }
  }
}

function checkGitIndex() {
  const stat = statSync(gitIndexPath, { throwIfNoEntry: false });
  if (stat === undefined || !stat.isFile()) {
    return;
  }

  const gitIndex = readFileSync(gitIndexPath, { flag: "r" });

  if (gitIndex.includes(Buffer.from(".local/"))) {
    failures.push(".local/ appears in the Git index. Remove tracked local helper files before committing.");
  }
}

function shouldSkip(filePath) {
  return excludedPathPatterns.some((pattern) => pattern.test(filePath));
}

function isTextFile(filePath) {
  return textExtensions.has(extname(filePath).toLowerCase());
}

function lineNumberForIndex(content, index) {
  return content.slice(0, index).split(/\r?\n/).length;
}

function normalizePath(value) {
  return value.replaceAll("\\", "/").replace(/^\.\//, "");
}
