#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
expected_permission_set="AwsSftpServer-Operator"
expected_account_id=""
no_browser="false"
use_device_code="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/login.sh [--profile <profile>] [options]
  scripts/login.sh <profile> [options]

Sign in to the configured IAM Identity Center profile used for routine
SFTP server operation, then confirm the resulting AWS caller identity.

Options:
  --profile <profile>              Local AWS CLI profile to sign in with.
                                   Defaults to AWS_SFTP_SERVER_PROFILE or aws-sftp-server-operator.
  --expected-permission-set <name> Expected SSO role name. Defaults to AwsSftpServer-Operator.
  --expected-account-id <id>       Optional expected AWS account ID from local profile config.
  --no-browser                     Do not automatically open a browser.
  --use-device-code                Use device-code login flow.
  -h, --help                       Show this help.

Do not commit profile names, account IDs, or command output.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || fail "--profile requires a value."
      profile="$2"
      shift 2
      ;;
    --expected-permission-set)
      [[ $# -ge 2 ]] || fail "--expected-permission-set requires a value."
      expected_permission_set="$2"
      shift 2
      ;;
    --expected-account-id)
      [[ $# -ge 2 ]] || fail "--expected-account-id requires a value."
      expected_account_id="$2"
      shift 2
      ;;
    --no-browser)
      no_browser="true"
      shift
      ;;
    --use-device-code)
      use_device_code="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" == --* ]]; then
        fail "Unknown argument: $1"
      fi

      profile="$1"
      shift
      ;;
  esac
done

require_command aws
[[ -n "$profile" ]] || fail "Profile is required."
validate_bootstrap_name "$expected_permission_set" "expected permission set name"

configured_role="$(aws configure get sso_role_name --profile "$profile" || true)"
configured_account_id="$(aws configure get sso_account_id --profile "$profile" || true)"

[[ -n "$configured_role" ]] || fail "Profile does not have sso_role_name configured. Run aws configure sso for this local profile."
[[ "$configured_role" == "$expected_permission_set" ]] || fail "Profile is configured for SSO role '$configured_role', expected '$expected_permission_set'."

if [[ -n "$expected_account_id" ]]; then
  [[ "$expected_account_id" =~ ^[0-9]{12}$ ]] || fail "--expected-account-id must be a 12-digit AWS account ID."
  [[ "$configured_account_id" == "$expected_account_id" ]] || fail "Profile is configured for a different AWS account than --expected-account-id."
fi

login_args=(--profile "$profile")
if [[ "$no_browser" == "true" ]]; then
  login_args+=(--no-browser)
fi
if [[ "$use_device_code" == "true" ]]; then
  login_args+=(--use-device-code)
fi

printf 'Routine AWS login: IAM Identity Center operator profile\n'
printf '\n'
printf 'This command signs in a local AWS CLI profile for routine testbed operation.\n'
printf 'Do not commit profile names, account IDs, or command output.\n'
printf '\n'
printf 'Profile checks:\n'
printf '  SSO role name: %s\n' "$configured_role"
printf '  Configured account ID: <local profile value; do not commit>\n'
printf '\n'

aws sso login "${login_args[@]}"

printf '\n'
printf 'Signed in. Current caller identity for routine profile:\n'
aws sts get-caller-identity \
  --profile "$profile" \
  --query '{Account:Account, Arn:Arn, UserId:UserId}' \
  --output table

printf '\n'
printf 'Routine login complete. Use this profile for deploy, describe, start, stop, destroy, parameter update, and smoke-test commands.\n'
