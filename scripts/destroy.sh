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
delete_parameter="true"
parameter_name="/aws-sftp-server/connection"

usage() {
  cat <<'USAGE'
Usage:
  scripts/destroy.sh --approve-destroy [options]

Delete the CloudFormation-managed SFTP runtime stack and remove the published
connection parameter by default. This does not delete the durable AWS account,
IAM Identity Center assignment, or local AWS profiles.

Required:
  --approve-destroy    Explicitly approve runtime stack deletion.

Options:
  --profile <profile>  AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                       or aws-sftp-server-operator.
  --region <region>    AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                       or us-west-1.
  --stack-name <name>  CloudFormation stack name. Defaults to aws-sftp-server.
  --keep-parameter     Preserve the project-owned connection parameter.
  --parameter-name <name>
                       Parameter Store connection parameter. Defaults to
                       /aws-sftp-server/connection.
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
    --keep-parameter)
      delete_parameter="false"
      shift
      ;;
    --parameter-name)
      [[ $# -ge 2 ]] || fail "--parameter-name requires a value."
      parameter_name="$2"
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
[[ "$parameter_name" == /* ]] || fail "--parameter-name must start with /."

if [[ "$approved_destroy" != "true" ]]; then
  fail "Refusing runtime stack deletion without --approve-destroy."
fi

printf 'Destroy AWS SFTP testbed runtime stack\n'
printf '\n'
printf 'This command deletes CloudFormation-managed runtime resources.\n'
printf 'It deletes the published connection parameter by default to avoid stale endpoint data.\n'
printf '\n'
printf 'Stack name: %s\n' "$stack_name"
printf 'Region: %s\n' "$region"
printf 'Connection parameter deletion: %s\n' "$delete_parameter"
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

if [[ "$delete_parameter" == "true" ]]; then
  printf 'Deleting project-owned connection parameter...\n'
  if ! aws ssm delete-parameter \
    --profile "$profile" \
    --region "$region" \
    --name "$parameter_name"; then
    fail "Unable to delete connection parameter."
  fi
else
  printf 'Connection parameter preserved by explicit --keep-parameter.\n'
fi

printf 'Destroy complete. CloudFormation-managed runtime resources have been deleted.\n'
