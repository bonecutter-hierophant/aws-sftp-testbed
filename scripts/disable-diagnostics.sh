#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
wait_for_update="true"

usage() {
  cat <<'USAGE'
Usage:
  scripts/disable-diagnostics.sh [options]

Remove the temporary SSM diagnostics instance profile from an existing SFTP
testbed stack after source-IP diagnosis is complete.

Options:
  --profile <profile>  AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                       or aws-sftp-server-operator.
  --region <region>    AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                       or us-west-1.
  --stack-name <name>  CloudFormation stack name. Defaults to aws-sftp-server.
  --no-wait            Do not wait for stack update completion.
  -h, --help           Show this help.
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
    --no-wait)
      wait_for_update="false"
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

printf 'Disable SFTP source-IP diagnostics\n'
printf '\n'
printf 'This command updates an existing stack to remove the temporary SSM diagnostics instance profile.\n'
printf 'It does not change the SFTP security group or credentials.\n'
printf '\n'
printf 'Stack name: %s\n' "$stack_name"
printf 'Region: %s\n' "$region"
printf '\n'

set +e
update_output="$(aws cloudformation update-stack \
  --profile "$profile" \
  --region "$region" \
  --stack-name "$stack_name" \
  --use-previous-template \
  --parameters \
    ParameterKey=AllowedCidr,UsePreviousValue=true \
    ParameterKey=AllowPublicCidr,UsePreviousValue=true \
    ParameterKey=InstanceType,UsePreviousValue=true \
    ParameterKey=VpcId,UsePreviousValue=true \
    ParameterKey=SubnetId,UsePreviousValue=true \
    ParameterKey=LatestAmiId,UsePreviousValue=true \
    ParameterKey=ProjectName,UsePreviousValue=true \
    ParameterKey=SftpUsername,UsePreviousValue=true \
    ParameterKey=SftpPassword,UsePreviousValue=true \
    ParameterKey=EnableSsmDiagnostics,ParameterValue=false \
  --capabilities CAPABILITY_NAMED_IAM 2>&1)"
update_status=$?
set -e

if [[ "$update_status" -ne 0 ]]; then
  if [[ "$update_output" == *"No updates are to be performed"* ]]; then
    printf 'Diagnostics are already disabled.\n'
    exit 0
  fi

  printf '%s\n' "$update_output" >&2
  exit "$update_status"
fi

printf '%s\n' "$update_output"

if [[ "$wait_for_update" == "true" ]]; then
  printf 'Waiting for diagnostics disablement to complete...\n'
  aws cloudformation wait stack-update-complete \
    --profile "$profile" \
    --region "$region" \
    --stack-name "$stack_name"
fi

printf 'Diagnostics disabled. The SFTP server remains otherwise unchanged.\n'
