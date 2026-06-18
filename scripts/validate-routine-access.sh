#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
expected_permission_set="AwsSftpServer-Operator"

usage() {
  cat <<'USAGE'
Usage:
  scripts/validate-routine-access.sh [--profile <profile>] [options]
  scripts/validate-routine-access.sh <profile> [options]

Validate that the routine IAM Identity Center profile is active and does not
have AWS Organizations bootstrap authority.

Options:
  --profile <profile>              Local AWS CLI profile to validate.
                                   Defaults to AWS_SFTP_SERVER_PROFILE or aws-sftp-server-operator.
  --expected-permission-set <name> Expected SSO role name. Defaults to AwsSftpServer-Operator.
  -h, --help                       Show this help.

Do not commit profile names, account IDs, ARNs, or command output.
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
[[ "$configured_role" == "$expected_permission_set" ]] || fail "Profile is configured for SSO role '$configured_role', expected '$expected_permission_set'."

printf 'Validate routine AWS access\n'
printf '\n'
printf 'This command confirms the routine profile and checks that bootstrap authority is denied.\n'
printf 'Do not commit profile names, account IDs, ARNs, or command output.\n'
printf '\n'

printf 'Current routine caller identity:\n'
aws sts get-caller-identity \
  --profile "$profile" \
  --query '{Account:Account, Arn:Arn, UserId:UserId}' \
  --output table
printf '\n'

printf 'Checking that AWS Organizations bootstrap access is denied...\n'
set +e
organizations_output="$(aws organizations describe-organization --profile "$profile" --output text 2>&1)"
organizations_status=$?
set -e

if [[ "$organizations_status" -eq 0 ]]; then
  printf '%s\n' "$organizations_output"
  fail "Routine profile can describe AWS Organizations; expected access denied."
fi

if [[ "$organizations_output" != *"AccessDenied"* && "$organizations_output" != *"not authorized"* ]]; then
  printf '%s\n' "$organizations_output"
  fail "Organizations check failed for an unexpected reason."
fi

printf 'Organizations bootstrap access is denied as expected.\n'
printf 'Routine access validation complete.\n'
