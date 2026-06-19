#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
parameter_name="/sftp-testbed/aws-sftp-server/connection"
show_sensitive="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/update-parameter.sh [options]

Create or update the project-owned SSM Parameter Store SecureString connection
parameter from current CloudFormation outputs and the local generated
credentials file.

Options:
  --profile <profile>        AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                             or aws-sftp-server-operator.
  --region <region>          AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                             or us-west-1.
  --stack-name <name>        CloudFormation stack name. Defaults to aws-sftp-server.
  --parameter-name <name>    SSM parameter name. Defaults to
                             /sftp-testbed/aws-sftp-server/connection.
  show-sensitive,
  --show-sensitive           Print the parameter JSON. Avoid in shared terminals.
  -h, --help                 Show this help.

Do not commit parameter payloads, generated credentials, stack outputs, or command output.
USAGE
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf '%s' "$value"
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
    --stack-name)
      [[ $# -ge 2 ]] || fail "--stack-name requires a value."
      stack_name="$2"
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
validate_bootstrap_name "$stack_name" "stack name"
[[ "$parameter_name" == /* ]] || fail "--parameter-name must start with /."
load_stack_credentials "$stack_name"

host="$(stack_output "$profile" "$region" "$stack_name" PublicDnsName)"
public_ip="$(stack_output "$profile" "$region" "$stack_name" PublicIp)"
username="$(stack_output "$profile" "$region" "$stack_name" SftpUsername)"
remote_path="$(stack_output "$profile" "$region" "$stack_name" RemotePath)"
port="$(stack_output "$profile" "$region" "$stack_name" SftpPort)"
project_name="$(stack_output "$profile" "$region" "$stack_name" ProjectName)"
host_key_fingerprints=""

[[ -n "$host" && "$host" != "None" ]] || fail "Stack output PublicDnsName is not available."

if command -v ssh-keyscan >/dev/null 2>&1 && command -v ssh-keygen >/dev/null 2>&1; then
  host_key_fingerprints="$(ssh-keyscan -p "$port" -T 5 "$host" 2>/dev/null | ssh-keygen -lf - 2>/dev/null || true)"
fi

parameter_json="$(cat <<JSON
{
  "schemaVersion": 1,
  "protocol": "sftp",
  "host": "$(json_escape "$host")",
  "publicIp": "$(json_escape "$public_ip")",
  "port": $port,
  "username": "$(json_escape "$username")",
  "password": "$(json_escape "$SFTP_PASSWORD")",
  "remotePath": "$(json_escape "$remote_path")",
  "hostKeyFingerprints": "$(json_escape "$host_key_fingerprints")",
  "projectName": "$(json_escape "$project_name")"
}
JSON
)"

printf 'Update SSM Parameter Store SFTP connection parameter\n'
printf '\n'
printf 'This command writes current connection details and generated credentials to a SecureString parameter.\n'
printf 'Do not commit parameter payloads, generated credentials, stack outputs, or command output.\n'
printf '\n'
printf 'Parameter name: %s\n' "$parameter_name"
printf 'Host: %s\n' "$host"
printf 'Username: %s\n' "$username"
printf 'Remote path: %s\n' "$remote_path"
if [[ -n "$host_key_fingerprints" ]]; then
  printf 'Host key fingerprints: available\n'
else
  printf 'Host key fingerprints: unavailable; host may still be starting or local SSH tools may be missing\n'
fi
if [[ "$show_sensitive" == "true" ]]; then
  printf 'Parameter payload:\n%s\n' "$parameter_json"
else
  printf 'Parameter payload: <redacted; use --show-sensitive only when needed>\n'
fi
printf '\n'

aws ssm put-parameter \
  --profile "$profile" \
  --region "$region" \
  --name "$parameter_name" \
  --type SecureString \
  --tier Standard \
  --overwrite \
  --value "$parameter_json" >/dev/null

printf 'Parameter update complete.\n'
