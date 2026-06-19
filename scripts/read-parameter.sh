#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
parameter_name="/sftp-testbed/aws-sftp-server/connection"
show_sensitive="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/read-parameter.sh [options]

Read the project-owned SSM Parameter Store SecureString connection parameter.

Options:
  --profile <profile>        AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                             or aws-sftp-server-operator.
  --region <region>          AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                             or us-west-1.
  --parameter-name <name>    SSM parameter name. Defaults to
                             /sftp-testbed/aws-sftp-server/connection.
  show-sensitive,
  --show-sensitive           Print the decrypted password. Avoid in shared terminals.
  -h, --help                 Show this help.

Do not commit decrypted parameter payloads, credentials, or command output.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || fail "--profile requires a value."
      profile="$2"
      shift 2
      ;;
    --region)
      [[ $# -ge 2 ]] || fail "--region requires a value."
      region="$2"
      shift 2
      ;;
    --parameter-name)
      [[ $# -ge 2 ]] || fail "--parameter-name requires a value."
      parameter_name="$2"
      shift 2
      ;;
    --show-sensitive|show-sensitive)
      show_sensitive="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command aws
require_command node
[[ "$parameter_name" == /* ]] || fail "--parameter-name must start with /."

parameter_json="$(aws ssm get-parameter \
  --profile "$profile" \
  --region "$region" \
  --name "$parameter_name" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)"

printf '%s' "$parameter_json" | node -e '
const fs = require("node:fs");
const showSensitive = process.argv.includes("--show-sensitive");
const input = fs.readFileSync(0, "utf8");
const value = JSON.parse(input);

console.log("SFTP connection parameter");
console.log("");
console.log(`Schema version: ${value.schemaVersion || ""}`);
console.log(`Protocol: ${value.protocol || ""}`);
console.log(`Host: ${value.host || ""}`);
console.log(`Public IP: ${value.publicIp || ""}`);
console.log(`Port: ${value.port || ""}`);
console.log(`Username: ${value.username || ""}`);
console.log(`Password: ${showSensitive ? value.password || "" : "<redacted; use --show-sensitive only when needed>"}`);
console.log(`Remote path: ${value.remotePath || ""}`);
console.log(`Project name: ${value.projectName || ""}`);
console.log(`Host key fingerprints: ${value.hostKeyFingerprints ? "available" : "unavailable"}`);
' -- "$([[ "$show_sensitive" == "true" ]] && printf -- '--show-sensitive')"
