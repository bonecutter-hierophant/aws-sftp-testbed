#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
source "$script_dir/../../scripts/lib/common.sh"

bootstrap_selected="false"
sso_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
aws_args=()

usage() {
  cat <<'USAGE'
Usage:
  bootstrap/scripts/inspect.sh --bootstrap [--profile <profile>] [--sso-region <region>]

Read-only bootstrap discovery. This command contacts AWS and prints current
caller, AWS Organizations, and IAM Identity Center visibility for review.

Required:
  --bootstrap             Explicitly select the high-privilege bootstrap lane.

Options:
  --profile <profile>     AWS CLI profile to use. Prefer local-only profile names.
  --sso-region <region>   IAM Identity Center region. Defaults to AWS_REGION,
                          AWS_DEFAULT_REGION, or us-west-1.
  -h, --help              Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      bootstrap_selected="true"
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || fail "--profile requires a value."
      aws_args+=(--profile "$2")
      shift 2
      ;;
    --sso-region)
      [[ $# -ge 2 ]] || fail "--sso-region requires a value."
      sso_region="$2"
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

printf 'Bootstrap inspect: read-only AWS discovery\n'
printf '\n'
printf 'This command may print private AWS account identifiers to your terminal.\n'
printf 'Do not commit command output, account IDs, ARNs, identity store IDs, or profile names.\n'
printf '\n'

printf 'Current AWS caller:\n'
aws "${aws_args[@]}" sts get-caller-identity \
  --query '{Account:Account, Arn:Arn, UserId:UserId}' \
  --output table
printf '\n'

printf 'AWS Organizations summary:\n'
aws "${aws_args[@]}" organizations describe-organization \
  --query '{FeatureSet:Organization.FeatureSet, MasterAccountId:Organization.MasterAccountId, AvailablePolicyTypes:Organization.AvailablePolicyTypes[].Type}' \
  --output table
printf '\n'

printf 'AWS Organizations accounts:\n'
aws "${aws_args[@]}" organizations list-accounts \
  --query 'Accounts[].{Name:Name, Id:Id, Status:Status}' \
  --output table
printf '\n'

printf 'IAM Identity Center instances in %s:\n' "$sso_region"
aws "${aws_args[@]}" sso-admin list-instances \
  --region "$sso_region" \
  --query 'Instances[].{InstanceArn:InstanceArn, IdentityStoreId:IdentityStoreId}' \
  --output table
printf '\n'

printf 'Inspect complete. Review the output before approving any create or assignment phase.\n'
