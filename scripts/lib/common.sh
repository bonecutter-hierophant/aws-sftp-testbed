#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
}

require_allowed_cidr() {
  local allowed_cidr="${1:-}"
  local allow_public="${2:-false}"

  [[ -n "$allowed_cidr" ]] || fail "Allowed CIDR is required."

  if [[ "$allowed_cidr" == "0.0.0.0/0" && "$allow_public" != "true" ]]; then
    fail "Refusing 0.0.0.0/0 without an explicit temporary public override."
  fi
}

not_implemented() {
  local command_name="$1"
  fail "$command_name is scaffolded but not implemented yet."
}
