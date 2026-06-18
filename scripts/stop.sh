#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
wait_for_stopped="true"

usage() {
  cat <<'USAGE'
Usage:
  scripts/stop.sh [options]

Stop the EC2 instance in an existing SFTP testbed stack while preserving the
CloudFormation stack and attached EBS volume.

Options:
  --profile <profile>  AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                       or aws-sftp-server-operator.
  --region <region>    AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                       or us-west-1.
  --stack-name <name>  CloudFormation stack name. Defaults to aws-sftp-server.
  --no-wait            Do not wait for EC2 instance-stopped state.
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
      wait_for_stopped="false"
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

printf 'Stop AWS SFTP testbed instance\n'
printf '\n'
printf 'This command stops EC2 runtime compute but preserves stack resources.\n'
printf 'Use destroy.sh for full teardown when testing is complete.\n'
printf '\n'
printf 'Stack name: %s\n' "$stack_name"
printf 'Instance ID: %s\n' "$instance_id"
printf '\n'

aws ec2 stop-instances \
  --profile "$profile" \
  --region "$region" \
  --instance-ids "$instance_id" \
  --output table

if [[ "$wait_for_stopped" == "true" ]]; then
  printf '\nWaiting for instance-stopped state...\n'
  aws ec2 wait instance-stopped \
    --profile "$profile" \
    --region "$region" \
    --instance-ids "$instance_id"
fi

printf '\n%s\n' "Instance stopped. EC2 instance usage charges should stop, but attached EBS volumes and some other resources may still incur charges. Use destroy.sh for full teardown."
