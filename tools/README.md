# Tools

This directory owns repo-local verification helpers.

These tools are intentionally sandbox-safe. They inspect committed files and repository structure without contacting AWS or mutating cloud resources.

`run-bash-script.mjs` is the local npm wrapper for Bash entrypoints. On Windows it prefers Git Bash when available so npm scripts do not accidentally resolve to the WSL stub.

Verification helpers:

- `check-structure.mjs`: required repository shape and owner docs
- `check-public-sanitization.mjs`: public-repo hygiene scan
- `check-shell-static.mjs`: shell entrypoint shape and critical guard checks
- `check-cloudformation-static.mjs`: CloudFormation safety shape
- `check-bootstrap-static.mjs`: bootstrap lane and approval-gate shape
- `check-docs-whitespace.mjs`: trailing whitespace scan
- `run-verification.mjs`: stable gate runner and recommendation helper
