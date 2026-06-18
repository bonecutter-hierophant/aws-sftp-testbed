#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
wait_for_running="true"
parameter_name="/aws-sftp-server/connection"
skip_parameter_update="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/start.sh [options]

Start the EC2 instance in an existing SFTP testbed stack.

Options:
  --profile <profile>  AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                       or aws-sftp-server-operator.
  --region <region>    AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                       or us-west-1.
  --stack-name <name>  CloudFormation stack name. Defaults to aws-sftp-server.
  --parameter-name <name> SSM Parameter Store name. Defaults to
                          /aws-sftp-server/connection.
  --skip-parameter-update Do not refresh Parameter Store after start.
  --no-wait            Do not wait for EC2 instance-running state.
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
    --parameter-name)
      [[ $# -ge 2 ]] || fail "--parameter-name requires a value."
      parameter_name="$2"
      shift 2
      ;;
    --skip-parameter-update)
      skip_parameter_update="true"
      shift
      ;;
    --no-wait)
      wait_for_running="false"
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

instance_id="$(stack_instance_id "$profile" "$region" "$stack_name")"
[[ -n "$instance_id" && "$instance_id" != "None" ]] || fail "Unable to find instance ID from stack outputs."

printf 'Start AWS SFTP testbed instance\n'
printf '\n'
printf 'This command starts an existing EC2 runtime resource and may change public IP/DNS.\n'
printf 'Do not commit command output or generated connection details.\n'
printf '\n'
printf 'Stack name: %s\n' "$stack_name"
printf 'Instance ID: %s\n' "$instance_id"
printf '\n'

aws ec2 start-instances \
  --profile "$profile" \
  --region "$region" \
  --instance-ids "$instance_id" \
  --output table

if [[ "$wait_for_running" == "true" ]]; then
  printf '\nWaiting for instance-running state...\n'
  aws ec2 wait instance-running \
    --profile "$profile" \
    --region "$region" \
    --instance-ids "$instance_id"
fi

if [[ "$skip_parameter_update" != "true" ]]; then
  printf '\nRefreshing SSM Parameter Store connection parameter...\n'
  "$script_dir/update-parameter.sh" \
    --profile "$profile" \
    --region "$region" \
    --stack-name "$stack_name" \
    --parameter-name "$parameter_name"
fi

printf '\nStart complete. Run describe.sh to see the current public endpoint.\n'
