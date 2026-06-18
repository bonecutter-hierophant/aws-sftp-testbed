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

require_bootstrap_selected() {
  local selected="${1:-false}"

  [[ "$selected" == "true" ]] || fail "Refusing bootstrap command without --bootstrap. This lane uses management-account visibility."
}

validate_bootstrap_name() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{1,63}$ ]] || fail "Invalid $label: use 2-64 letters, numbers, dots, underscores, or hyphens."
}

validate_positive_integer() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "Invalid $label: expected a positive integer."
}

validate_sftp_username() {
  local value="$1"

  [[ "$value" =~ ^[a-z_][a-z0-9_-]{1,31}$ ]] || fail "Invalid SFTP username: use 2-32 lowercase letters, numbers, underscores, or hyphens, starting with a letter or underscore."
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
