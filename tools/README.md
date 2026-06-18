# Tools

This directory owns repo-local verification helpers.

These tools are intentionally sandbox-safe. They inspect committed files and repository structure without contacting AWS or mutating cloud resources.

`run-bash-script.mjs` is the local npm wrapper for Bash entrypoints. On Windows it prefers Git Bash when available so npm scripts do not accidentally resolve to the WSL stub.
