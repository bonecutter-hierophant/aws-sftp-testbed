#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
approved_destroy="false"
wait_for_delete="true"

usage() {
  cat <<'USAGE'
Usage:
  scripts/destroy.sh --approve-destroy [options]

Delete the CloudFormation-managed SFTP runtime stack. This does not delete the
durable AWS account, IAM Identity Center assignment, local AWS profiles, or any
project-owned Secrets Manager secret.

Required:
  --approve-destroy    Explicitly approve runtime stack deletion.

Options:
  --profile <profile>  AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                       or aws-sftp-server-operator.
  --region <region>    AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                       or us-west-1.
  --stack-name <name>  CloudFormation stack name. Defaults to aws-sftp-server.
  --no-wait            Do not wait for stack deletion to complete.
  -h, --help           Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --approve-destroy|approve-destroy)
      approved_destroy="true"
      shift
      ;;
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
    --no-wait)
      wait_for_delete="false"
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

if [[ "$approved_destroy" != "true" ]]; then
  fail "Refusing runtime stack deletion without --approve-destroy."
fi

printf 'Destroy AWS SFTP testbed runtime stack\n'
printf '\n'
printf 'This command deletes CloudFormation-managed runtime resources.\n'
printf 'It does not delete durable AWS account access or project-owned Secrets Manager secrets.\n'
printf '\n'
printf 'Stack name: %s\n' "$stack_name"
printf 'Region: %s\n' "$region"
printf '\n'

aws cloudformation delete-stack \
  --profile "$profile" \
  --region "$region" \
  --stack-name "$stack_name"

if [[ "$wait_for_delete" == "true" ]]; then
  printf 'Waiting for stack deletion to complete...\n'
  aws cloudformation wait stack-delete-complete \
    --profile "$profile" \
    --region "$region" \
    --stack-name "$stack_name"
fi

printf 'Destroy complete. CloudFormation-managed runtime resources have been deleted.\n'
