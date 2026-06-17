#!/usr/bin/env node
import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const failures = [];

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
  checkWhitespace(filePath, content);
}

if (failures.length > 0) {
  console.error("Documentation whitespace check failed:");
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

function checkWhitespace(filePath, content) {
  const lines = content.split(/\r?\n/);

  lines.forEach((line, index) => {
    if (/[ \t]+$/.test(line)) {
      failures.push(`${filePath}:${index + 1} has trailing whitespace`);
    }
  });
}

function shouldSkip(filePath) {
  return excludedPathPatterns.some((pattern) => pattern.test(filePath));
}

function isTextFile(filePath) {
  return textExtensions.has(extname(filePath).toLowerCase());
}

function normalizePath(value) {
  return value.replaceAll("\\", "/").replace(/^\.\//, "");
}
