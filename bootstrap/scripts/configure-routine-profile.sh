#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
source "$script_dir/../../scripts/lib/common.sh"

bootstrap_selected="false"
approved_local_profile="false"
bootstrap_profile="${AWS_SFTP_BOOTSTRAP_PROFILE:-}"
routine_profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
account_name="aws-sftp-server"
permission_set_name="AwsSftpServer-Operator"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
sso_session="${AWS_SFTP_SSO_SESSION:-}"

usage() {
  cat <<'USAGE'
Usage:
  bootstrap/scripts/configure-routine-profile.sh --bootstrap --approve-local-profile [options]

Create or update the local AWS CLI profile used for routine SFTP server
operation. This command writes local AWS CLI configuration and reads AWS
Organizations to discover the project account ID.

Required:
  --bootstrap                  Explicitly select the bootstrap lane.
  --approve-local-profile      Approve writing local AWS CLI profile config.

Options:
  --bootstrap-profile <name>   Local management/admin profile used only for discovery.
                               Defaults to AWS_SFTP_BOOTSTRAP_PROFILE or a discovered
                               signed-in profile with AWS Organizations access.
  --routine-profile <name>     Routine profile to write. Defaults to
                               AWS_SFTP_SERVER_PROFILE or aws-sftp-server-operator.
  --account-name <name>        AWS Organizations account name. Defaults to aws-sftp-server.
  --permission-set-name <name> Permission set name. Defaults to AwsSftpServer-Operator.
  --sso-session <name>         Existing local AWS CLI SSO session to reuse. Defaults
                               to AWS_SFTP_SSO_SESSION or the first configured SSO session.
  --region <region>            Default AWS region for the routine profile. Defaults to us-west-1.
  -h, --help                   Show this help.

Do not commit profile names, account IDs, SSO start URLs, or command output.
USAGE
}

find_first_sso_session() {
  local profile_name
  local session_name

  while read -r profile_name; do
    [[ -n "$profile_name" ]] || continue
    session_name="$(aws configure get sso_session --profile "$profile_name" || true)"
    if [[ -n "$session_name" ]]; then
      printf '%s\n' "$session_name"
      return 0
    fi
  done < <(aws configure list-profiles | tr -d '\r')

  return 1
}

find_bootstrap_profile() {
  local profile_name
  local login_session
  local candidates=()

  while read -r profile_name; do
    [[ -n "$profile_name" ]] || continue
    login_session="$(aws configure get login_session --profile "$profile_name" || true)"
    if [[ -n "$login_session" ]]; then
      candidates+=("$profile_name")
    fi
  done < <(aws configure list-profiles | tr -d '\r')

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    fail "No local AWS console-login profiles found. Sign in with AWS CLI console credentials or pass --bootstrap-profile."
  fi

  for profile_name in "${candidates[@]}"; do
    if aws --profile "$profile_name" organizations describe-organization --query 'Organization.Id' --output text >/dev/null 2>&1; then
      printf '%s\n' "$profile_name"
      return 0
    fi
  done

  fail "No signed-in local profile with AWS Organizations access was found. Sign in to the management account or pass --bootstrap-profile."
}

find_account_id() {
  local target_name="$1"
  local account_id

  account_id="$(aws --profile "$bootstrap_profile" organizations list-accounts \
    --query "Accounts[?Name=='$target_name' && Status=='ACTIVE'].Id | [0]" \
    --output text)"

  [[ -n "$account_id" && "$account_id" != "None" ]] || fail "Active AWS Organizations account not found: $target_name"
  printf '%s\n' "$account_id"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      bootstrap_selected="true"
      shift
      ;;
    --approve-local-profile)
      approved_local_profile="true"
      shift
      ;;
    --bootstrap-profile)
      [[ $# -ge 2 ]] || fail "--bootstrap-profile requires a value."
      bootstrap_profile="$2"
      shift 2
      ;;
    --routine-profile)
      [[ $# -ge 2 ]] || fail "--routine-profile requires a value."
      routine_profile="$2"
      shift 2
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
    --sso-session)
      [[ $# -ge 2 ]] || fail "--sso-session requires a value."
      sso_session="$2"
      shift 2
      ;;
    --region)
      [[ $# -ge 2 ]] || fail "--region requires a value."
      region="$2"
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
[[ -n "$routine_profile" ]] || fail "Routine profile is required."

if [[ "$approved_local_profile" != "true" ]]; then
  fail "Refusing local AWS profile changes without --approve-local-profile."
fi

if [[ -z "$bootstrap_profile" ]]; then
  bootstrap_profile="$(find_bootstrap_profile)"
fi

if [[ -z "$sso_session" ]]; then
  sso_session="$(find_first_sso_session)" || fail "No local AWS CLI SSO session found. Run aws configure sso-session first or pass --sso-session."
fi

account_id="$(find_account_id "$account_name")"

printf 'Configure local routine AWS profile\n'
printf '\n'
printf 'This command writes local AWS CLI configuration outside the repository.\n'
printf 'Do not commit profile names, account IDs, SSO start URLs, or command output.\n'
printf '\n'
printf 'Planned local profile:\n'
printf '  Routine profile: %s\n' "$routine_profile"
printf '  Account name: %s\n' "$account_name"
printf '  Account ID: <discovered at runtime; do not commit>\n'
printf '  Permission set: %s\n' "$permission_set_name"
printf '  SSO session: <local config value; do not commit>\n'
printf '  Region: %s\n' "$region"
printf '  Bootstrap profile: <discovered or provided local profile; do not commit>\n'
printf '\n'

aws configure set sso_session "$sso_session" --profile "$routine_profile"
aws configure set sso_account_id "$account_id" --profile "$routine_profile"
aws configure set sso_role_name "$permission_set_name" --profile "$routine_profile"
aws configure set region "$region" --profile "$routine_profile"
aws configure set output json --profile "$routine_profile"

printf 'Local routine profile configured. Next phase: run scripts/login.sh or npm run login.\n'
