#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
skip_host_key="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/describe.sh [options]

Print non-sensitive CloudFormation stack and SFTP endpoint details.

Options:
  --profile <profile>    AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                         or aws-sftp-server-operator.
  --region <region>      AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                         or us-west-1.
  --stack-name <name>    CloudFormation stack name. Defaults to aws-sftp-server.
  --skip-host-key        Do not attempt ssh-keyscan fingerprint discovery.
  -h, --help             Show this help.

This command does not print SFTP passwords or private key material.
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
    --stack-name)
      [[ $# -ge 2 ]] || fail "--stack-name requires a value."
      stack_name="$2"
      shift 2
      ;;
    --skip-host-key)
      skip_host_key="true"
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

printf 'Describe AWS SFTP testbed stack\n'
printf '\n'
printf 'This command prints non-sensitive stack and endpoint details.\n'
printf 'Do not commit stack outputs, account IDs, profile names, or generated credentials.\n'
printf '\n'

stack_status_value="$(stack_status "$profile" "$region" "$stack_name")"

instance_id="$(stack_output "$profile" "$region" "$stack_name" InstanceId)"
public_dns="$(stack_output "$profile" "$region" "$stack_name" PublicDnsName)"
public_ip="$(stack_output "$profile" "$region" "$stack_name" PublicIp)"
security_group_id="$(stack_output "$profile" "$region" "$stack_name" SecurityGroupId)"
sftp_port="$(stack_output "$profile" "$region" "$stack_name" SftpPort)"
sftp_username="$(stack_output "$profile" "$region" "$stack_name" SftpUsername)"
remote_path="$(stack_output "$profile" "$region" "$stack_name" RemotePath)"
project_name="$(stack_output "$profile" "$region" "$stack_name" ProjectName)"

printf 'Stack name: %s\n' "$stack_name"
printf 'Stack status: %s\n' "$stack_status_value"
printf 'Project name: %s\n' "$project_name"
printf 'Instance ID: %s\n' "$instance_id"
printf 'Security group ID: %s\n' "$security_group_id"
printf 'Public DNS: %s\n' "$public_dns"
printf 'Public IP: %s\n' "$public_ip"
printf 'SFTP port: %s\n' "$sftp_port"
printf 'SFTP username: %s\n' "$sftp_username"
printf 'Remote path: %s\n' "$remote_path"

if [[ "$skip_host_key" != "true" && -n "$public_dns" && "$public_dns" != "None" ]]; then
  if command -v ssh-keyscan >/dev/null 2>&1 && command -v ssh-keygen >/dev/null 2>&1; then
    printf 'Host key fingerprints:\n'
    if ! ssh-keyscan -p "$sftp_port" -T 5 "$public_dns" 2>/dev/null | ssh-keygen -lf -; then
      printf '  <unavailable; host may still be starting or unreachable from this network>\n'
    fi
  else
    printf 'Host key fingerprints: <unavailable; ssh-keyscan and ssh-keygen are required>\n'
  fi
fi
