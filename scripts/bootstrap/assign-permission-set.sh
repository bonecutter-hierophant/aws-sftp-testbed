#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$script_dir/../lib/common.sh"

bootstrap_selected="false"
approved_assignment="false"
account_name="aws-sftp-server"
permission_set_name="AwsSftpServer-Operator"
operator_username=""
sso_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
instance_arn=""
identity_store_id=""
poll_interval_seconds="10"
poll_max_attempts="30"
aws_args=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/bootstrap/assign-permission-set.sh --bootstrap --approve-assignment \
    --operator-username <username> [options]

Assign the project IAM Identity Center permission set to the operator user for
the dedicated AWS account. This command contacts AWS and changes durable IAM
Identity Center account access configuration.

Required:
  --bootstrap                  Explicitly select the high-privilege bootstrap lane.
  --approve-assignment         Approve this bounded account assignment phase.
  --operator-username <name>   IAM Identity Center username to receive access.

Options:
  --account-name <name>        AWS Organizations account name. Defaults to aws-sftp-server.
  --permission-set-name <name> Permission set name. Defaults to AwsSftpServer-Operator.
  --sso-region <region>        IAM Identity Center region. Defaults to AWS_REGION,
                               AWS_DEFAULT_REGION, or us-west-1.
  --instance-arn <arn>         IAM Identity Center instance ARN. Required only if
                               more than one instance is visible.
  --identity-store-id <id>     Identity Store ID. Usually discovered from the instance.
  --profile <profile>          AWS CLI profile to use. Prefer local-only profile names.
  --poll-interval <seconds>    Seconds between status checks. Defaults to 10.
  --poll-max-attempts <count>  Maximum status checks. Defaults to 30.
  -h, --help                   Show this help.

Do not commit usernames, account IDs, ARNs, identity store IDs, profile names, or command output.
USAGE
}

find_sso_instance() {
  local instances

  if [[ -n "$instance_arn" && -n "$identity_store_id" ]]; then
    return 0
  fi

  instances="$(aws "${aws_args[@]}" sso-admin list-instances \
    --region "$sso_region" \
    --query 'Instances[].join(`|`, [InstanceArn, IdentityStoreId])' \
    --output text)"

  mapfile -t instance_rows < <(printf '%s\n' "$instances" | tr '\t' '\n' | sed '/^$/d')

  if [[ "${#instance_rows[@]}" -eq 0 ]]; then
    fail "No IAM Identity Center instances found in $sso_region."
  fi

  if [[ "${#instance_rows[@]}" -gt 1 && -z "$instance_arn" ]]; then
    fail "Multiple IAM Identity Center instances found. Re-run with --instance-arn."
  fi

  for row in "${instance_rows[@]}"; do
    local row_instance_arn="${row%%|*}"
    local row_identity_store_id="${row#*|}"

    if [[ -z "$instance_arn" || "$instance_arn" == "$row_instance_arn" ]]; then
      instance_arn="$row_instance_arn"
      [[ -n "$identity_store_id" ]] || identity_store_id="$row_identity_store_id"
      return 0
    fi
  done

  fail "Unable to find requested IAM Identity Center instance."
}

find_account_id() {
  local target_name="$1"
  local account_id

  account_id="$(aws "${aws_args[@]}" organizations list-accounts \
    --query "Accounts[?Name=='$target_name' && Status=='ACTIVE'].Id | [0]" \
    --output text)"

  [[ -n "$account_id" && "$account_id" != "None" ]] || fail "Active AWS Organizations account not found: $target_name"
  printf '%s\n' "$account_id"
}

find_permission_set_arn() {
  local target_name="$1"
  local candidate_arn
  local candidate_name

  while read -r candidate_arn; do
    [[ -n "$candidate_arn" ]] || continue
    candidate_name="$(aws "${aws_args[@]}" sso-admin describe-permission-set \
      --region "$sso_region" \
      --instance-arn "$instance_arn" \
      --permission-set-arn "$candidate_arn" \
      --query 'PermissionSet.Name' \
      --output text)"

    if [[ "$candidate_name" == "$target_name" ]]; then
      printf '%s\n' "$candidate_arn"
      return 0
    fi
  done < <(aws "${aws_args[@]}" sso-admin list-permission-sets \
    --region "$sso_region" \
    --instance-arn "$instance_arn" \
    --query 'PermissionSets[]' \
    --output text | tr '\t' '\n' | sed '/^$/d')

  fail "Permission set not found: $target_name"
}

find_user_id() {
  local username="$1"
  local user_id

  user_id="$(aws "${aws_args[@]}" identitystore list-users \
    --region "$sso_region" \
    --identity-store-id "$identity_store_id" \
    --query "Users[?UserName=='$username'].UserId | [0]" \
    --output text)"

  [[ -n "$user_id" && "$user_id" != "None" ]] || fail "IAM Identity Center user not found: $username"
  printf '%s\n' "$user_id"
}

assignment_exists() {
  local account_id="$1"
  local permission_set_arn="$2"
  local user_id="$3"
  local existing

  existing="$(aws "${aws_args[@]}" sso-admin list-account-assignments \
    --region "$sso_region" \
    --instance-arn "$instance_arn" \
    --account-id "$account_id" \
    --permission-set-arn "$permission_set_arn" \
    --query "AccountAssignments[?PrincipalType=='USER' && PrincipalId=='$user_id'].PrincipalId | [0]" \
    --output text)"

  [[ -n "$existing" && "$existing" != "None" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      bootstrap_selected="true"
      shift
      ;;
    --approve-assignment)
      approved_assignment="true"
      shift
      ;;
    --account-name)
      [[ $# -ge 2 ]] || fail "--account-name requires a value."
      account_name="$2"
      shift 2
      ;;
    --permission-set-name)
      [[ $# -ge 2 ]] || fail "--permission-set-name requires a value."
      permission_set_name="$2"
      shift 2
      ;;
    --operator-username)
      [[ $# -ge 2 ]] || fail "--operator-username requires a value."
      operator_username="$2"
      shift 2
      ;;
    --sso-region)
      [[ $# -ge 2 ]] || fail "--sso-region requires a value."
      sso_region="$2"
      shift 2
      ;;
    --instance-arn)
      [[ $# -ge 2 ]] || fail "--instance-arn requires a value."
      instance_arn="$2"
      shift 2
      ;;
    --identity-store-id)
      [[ $# -ge 2 ]] || fail "--identity-store-id requires a value."
      identity_store_id="$2"
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
validate_bootstrap_name "$permission_set_name" "permission set name"
validate_positive_integer "$poll_interval_seconds" "poll interval"
validate_positive_integer "$poll_max_attempts" "poll max attempts"
[[ -n "$operator_username" ]] || fail "--operator-username is required."

if [[ "$approved_assignment" != "true" ]]; then
  fail "Refusing account assignment changes without --approve-assignment."
fi

printf 'Bootstrap assignment: IAM Identity Center account access\n'
printf '\n'
printf 'This command assigns durable IAM Identity Center account access.\n'
printf 'Do not commit command output, usernames, account IDs, ARNs, identity store IDs, or profile names.\n'
printf '\n'
printf 'Planned phase:\n'
printf '  Account name: %s\n' "$account_name"
printf '  Permission set name: %s\n' "$permission_set_name"
printf '  Operator username: <provided at runtime; do not commit>\n'
printf '  IAM Identity Center region: %s\n' "$sso_region"
printf '  Polling: %s attempts, %s seconds apart\n' "$poll_max_attempts" "$poll_interval_seconds"
printf '\n'

find_sso_instance
account_id="$(find_account_id "$account_name")"
permission_set_arn="$(find_permission_set_arn "$permission_set_name")"
user_id="$(find_user_id "$operator_username")"

if assignment_exists "$account_id" "$permission_set_arn" "$user_id"; then
  printf 'Assignment already exists for the requested user, account, and permission set.\n'
  printf 'Next phase: validate routine access using the assigned identity.\n'
  exit 0
fi

printf 'Creating account assignment...\n'
request_id="$(aws "${aws_args[@]}" sso-admin create-account-assignment \
  --region "$sso_region" \
  --instance-arn "$instance_arn" \
  --target-id "$account_id" \
  --target-type AWS_ACCOUNT \
  --permission-set-arn "$permission_set_arn" \
  --principal-type USER \
  --principal-id "$user_id" \
  --query 'AccountAssignmentCreationStatus.RequestId' \
  --output text)"

[[ -n "$request_id" && "$request_id" != "None" ]] || fail "AWS did not return an account assignment request ID."
printf 'Account assignment request submitted. Request ID: %s\n' "$request_id"
printf 'Polling account assignment status...\n'

for ((attempt = 1; attempt <= poll_max_attempts; attempt += 1)); do
  status_line="$(aws "${aws_args[@]}" sso-admin describe-account-assignment-creation-status \
    --region "$sso_region" \
    --instance-arn "$instance_arn" \
    --account-assignment-creation-request-id "$request_id" \
    --query 'AccountAssignmentCreationStatus.[Status,FailureReason]' \
    --output text)"

  read -r status failure_reason <<<"$status_line"
  printf '[%s/%s] status=%s\n' "$attempt" "$poll_max_attempts" "$status"

  if [[ "$status" == "SUCCEEDED" ]]; then
    printf 'Account assignment succeeded.\n'
    printf 'Next phase: validate routine access using the assigned identity.\n'
    exit 0
  fi

  if [[ "$status" == "FAILED" ]]; then
    fail "Account assignment failed: ${failure_reason:-unknown}"
  fi

  if [[ "$attempt" -lt "$poll_max_attempts" ]]; then
    sleep "$poll_interval_seconds"
  fi
done

fail "Account assignment did not finish within the polling window. Re-run inspection before continuing."
