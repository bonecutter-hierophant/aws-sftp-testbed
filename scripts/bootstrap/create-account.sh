#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$script_dir/../lib/common.sh"

bootstrap_selected="false"
approved_create="false"
account_name="aws-sftp-server"
account_email=""
role_name="OrganizationAccountAccessRole"
poll_interval_seconds="20"
poll_max_attempts="30"
aws_args=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/bootstrap/create-account.sh --bootstrap --approve-create-account \
    --account-email <email> [options]

Create the dedicated AWS Organizations member account for this project.
This command contacts AWS and creates durable account infrastructure.

Required:
  --bootstrap                  Explicitly select the high-privilege bootstrap lane.
  --approve-create-account     Approve this bounded account creation phase.
  --account-email <email>      Unique email address for the new AWS account.

Options:
  --account-name <name>        Account name. Defaults to aws-sftp-server.
  --role-name <name>           Cross-account role name created by AWS Organizations.
                               Defaults to OrganizationAccountAccessRole.
  --profile <profile>          AWS CLI profile to use. Prefer local-only profile names.
  --poll-interval <seconds>    Seconds between status checks. Defaults to 20.
  --poll-max-attempts <count>  Maximum status checks. Defaults to 30.
  -h, --help                   Show this help.

Do not commit account emails, account IDs, request IDs, profile names, or command output.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      bootstrap_selected="true"
      shift
      ;;
    --approve-create-account)
      approved_create="true"
      shift
      ;;
    --account-email)
      [[ $# -ge 2 ]] || fail "--account-email requires a value."
      account_email="$2"
      shift 2
      ;;
    --account-name)
      [[ $# -ge 2 ]] || fail "--account-name requires a value."
      account_name="$2"
      shift 2
      ;;
    --role-name)
      [[ $# -ge 2 ]] || fail "--role-name requires a value."
      role_name="$2"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || fail "--profile requires a value."
      aws_args+=(--profile "$2")
      shift 2
      ;;
    --poll-interval)
      [[ $# -ge 2 ]] || fail "--poll-interval requires a value."
      poll_interval_seconds="$2"
      shift 2
      ;;
    --poll-max-attempts)
      [[ $# -ge 2 ]] || fail "--poll-max-attempts requires a value."
      poll_max_attempts="$2"
      shift 2
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

require_bootstrap_selected "$bootstrap_selected"
require_command aws
validate_bootstrap_name "$account_name" "account name"
validate_bootstrap_name "$role_name" "role name"
validate_positive_integer "$poll_interval_seconds" "poll interval"
validate_positive_integer "$poll_max_attempts" "poll max attempts"
[[ -n "$account_email" ]] || fail "--account-email is required."
[[ "$account_email" == *@*.* ]] || fail "--account-email must look like an email address."

printf 'Bootstrap create account: AWS Organizations member account\n'
printf '\n'
printf 'This command creates durable AWS account infrastructure.\n'
printf 'Do not commit command output, account email, account IDs, request IDs, or profile names.\n'
printf '\n'
printf 'Planned phase:\n'
printf '  Account name: %s\n' "$account_name"
printf '  Account email: <provided at runtime; do not commit>\n'
printf '  Organizations role name: %s\n' "$role_name"
printf '  Polling: %s attempts, %s seconds apart\n' "$poll_max_attempts" "$poll_interval_seconds"
printf '\n'

existing_account="$(aws "${aws_args[@]}" organizations list-accounts \
  --query "Accounts[?Name=='$account_name'].[Id,Status]" \
  --output text)"

if [[ -n "$existing_account" ]]; then
  printf 'An AWS Organizations account named %s already exists:\n' "$account_name"
  printf '%s\n' "$existing_account"
  fail "Refusing to create a duplicate project account."
fi

if [[ "$approved_create" != "true" ]]; then
  fail "Refusing account creation without --approve-create-account."
fi

printf 'Creating AWS Organizations account...\n'
request_id="$(aws "${aws_args[@]}" organizations create-account \
  --account-name "$account_name" \
  --email "$account_email" \
  --role-name "$role_name" \
  --query 'CreateAccountStatus.Id' \
  --output text)"

[[ -n "$request_id" && "$request_id" != "None" ]] || fail "AWS did not return a create-account request ID."
printf 'Create account request submitted. Request ID: %s\n' "$request_id"
printf 'Polling account creation status...\n'

for ((attempt = 1; attempt <= poll_max_attempts; attempt += 1)); do
  status_line="$(aws "${aws_args[@]}" organizations describe-create-account-status \
    --create-account-request-id "$request_id" \
    --query 'CreateAccountStatus.[State,AccountId,FailureReason]' \
    --output text)"

  read -r state account_id failure_reason <<<"$status_line"
  printf '[%s/%s] state=%s\n' "$attempt" "$poll_max_attempts" "$state"

  if [[ "$state" == "SUCCEEDED" ]]; then
    printf 'Account creation succeeded. Account ID: %s\n' "$account_id"
    printf 'Next phase: create or update the IAM Identity Center permission set and account assignment.\n'
    exit 0
  fi

  if [[ "$state" == "FAILED" ]]; then
    fail "Account creation failed: ${failure_reason:-unknown}"
  fi

  if [[ "$attempt" -lt "$poll_max_attempts" ]]; then
    sleep "$poll_interval_seconds"
  fi
done

fail "Account creation did not finish within the polling window. Re-run inspection or check create-account status before continuing."
