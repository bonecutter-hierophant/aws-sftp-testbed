#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
keep_artifacts="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/smoke-test.sh [options]

Run an SFTP smoke test against the current testbed endpoint:
connect, upload, list, download, delete, and empty-directory check.

Options:
  --profile <profile>      AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                           or aws-sftp-server-operator.
  --region <region>        AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                           or us-west-1.
  --stack-name <name>      CloudFormation stack name. Defaults to aws-sftp-server.
  --keep-artifacts         Keep local smoke-test scratch files under .local/.
  -h, --help               Show this help.

Requires sshpass, sftp, and ssh-keyscan for password-based noninteractive testing.
Do not commit smoke-test artifacts, generated credentials, host keys, or command output.
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
    --keep-artifacts)
      keep_artifacts="true"
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
require_command sftp
require_command ssh-keyscan
require_command sshpass
validate_bootstrap_name "$stack_name" "stack name"
load_stack_credentials "$stack_name"

host="$(stack_output "$profile" "$region" "$stack_name" PublicDnsName)"
port="$(stack_output "$profile" "$region" "$stack_name" SftpPort)"
remote_path="$(stack_output "$profile" "$region" "$stack_name" RemotePath)"
[[ -n "$host" && "$host" != "None" ]] || fail "Stack output PublicDnsName is not available."

scratch_dir="$(repo_root)/.local/smoke-test-$stack_name"
known_hosts_file="$scratch_dir/known_hosts"
upload_file="$scratch_dir/upload.txt"
download_file="$scratch_dir/download.txt"
batch_file="$scratch_dir/sftp.batch"
remote_file="$remote_path/smoke-test-$(date +%Y%m%d%H%M%S).txt"

rm -rf "$scratch_dir"
mkdir -p "$scratch_dir"
chmod 700 "$scratch_dir" 2>/dev/null || true

if [[ "$keep_artifacts" != "true" ]]; then
  trap 'rm -rf "$scratch_dir"' EXIT
fi

printf 'aws-sftp-testbed smoke test\n' >"$upload_file"
printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$upload_file"

printf 'Collecting host key...\n'
ssh-keyscan -p "$port" -T 10 "$host" >"$known_hosts_file" 2>/dev/null
[[ -s "$known_hosts_file" ]] || fail "Unable to collect host key from $host:$port."

cat >"$batch_file" <<BATCH
put "$upload_file" "$remote_file"
ls "$remote_path"
get "$remote_file" "$download_file"
rm "$remote_file"
ls "$remote_path"
BATCH

printf 'Running SFTP smoke test against %s:%s...\n' "$host" "$port"
SSHPASS="$SFTP_PASSWORD" sshpass -e sftp \
  -P "$port" \
  -oBatchMode=no \
  -oStrictHostKeyChecking=yes \
  -oUserKnownHostsFile="$known_hosts_file" \
  -b "$batch_file" \
  "$SFTP_USERNAME@$host"

cmp "$upload_file" "$download_file" >/dev/null || fail "Downloaded file did not match uploaded file."

printf 'Smoke test passed: connect, upload, list, download, delete, and post-delete list completed.\n'
