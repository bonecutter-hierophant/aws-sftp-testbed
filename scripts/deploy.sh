#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
project_name="aws-sftp-server"
instance_type="t3.micro"
vpc_id=""
subnet_id=""
sftp_username="sftpuser"
allowed_cidr=""
allow_public_cidr="false"
show_sensitive="false"
parameter_name="/aws-sftp-server/connection"
skip_parameter_update="false"

usage() {
  cat <<'USAGE'
Usage:
  scripts/deploy.sh --allowed-cidr <cidr> [options]
  scripts/deploy.sh <cidr> [options]

Deploy or update the disposable AWS SFTP server CloudFormation stack.

Required:
  --allowed-cidr <cidr>        Source CIDR allowed to reach TCP 22.

Options:
  --allow-public-cidr          Temporarily allow AllowedCidr=0.0.0.0/0.
  --profile <profile>          AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                               or aws-sftp-server-operator.
  --region <region>            AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                               or us-west-1.
  --stack-name <name>          CloudFormation stack name. Defaults to aws-sftp-server.
  --project-name <name>        Project tag and resource prefix. Defaults to aws-sftp-server.
  --instance-type <type>       EC2 instance type. Defaults to t3.micro.
  --vpc-id <vpc-id>            VPC for the testbed. Defaults to the account default VPC.
  --subnet-id <subnet-id>      Public subnet for the instance. Defaults to a default subnet
                               in the selected VPC.
  --sftp-username <name>       SFTP username. Defaults to sftpuser.
  --parameter-name <name>      SSM Parameter Store name. Defaults to
                               /aws-sftp-server/connection.
  --skip-parameter-update      Do not refresh Parameter Store after deploy.
  --show-sensitive             Print the generated disposable SFTP password.
  -h, --help                   Show this help.

The generated password is written to .local/<stack-name>-credentials.env.
Do not commit local credentials, stack outputs, or generated AWS command output.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allowed-cidr)
      [[ $# -ge 2 ]] || fail "--allowed-cidr requires a value."
      allowed_cidr="$2"
      shift 2
      ;;
    --allow-public-cidr)
      allow_public_cidr="true"
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
    --project-name)
      [[ $# -ge 2 ]] || fail "--project-name requires a value."
      project_name="$2"
      shift 2
      ;;
    --instance-type)
      [[ $# -ge 2 ]] || fail "--instance-type requires a value."
      instance_type="$2"
      shift 2
      ;;
    --vpc-id)
      [[ $# -ge 2 ]] || fail "--vpc-id requires a value."
      vpc_id="$2"
      shift 2
      ;;
    --subnet-id)
      [[ $# -ge 2 ]] || fail "--subnet-id requires a value."
      subnet_id="$2"
      shift 2
      ;;
    --sftp-username)
      [[ $# -ge 2 ]] || fail "--sftp-username requires a value."
      sftp_username="$2"
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
    --show-sensitive)
      show_sensitive="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" == "allow-public-cidr" || "$1" == "allow-public" ]]; then
        allow_public_cidr="true"
        shift
        continue
      fi

      if [[ "$1" == --* ]]; then
        fail "Unknown argument: $1"
      fi

      if [[ -z "$allowed_cidr" ]]; then
        allowed_cidr="$1"
        shift
        continue
      fi

      fail "Unknown argument: $1"
      ;;
  esac
done

require_command aws
require_command openssl
require_allowed_cidr "$allowed_cidr" "$allow_public_cidr"
validate_bootstrap_name "$stack_name" "stack name"
validate_bootstrap_name "$project_name" "project name"
validate_sftp_username "$sftp_username"

if [[ -z "$vpc_id" ]]; then
  vpc_id="$(aws ec2 describe-vpcs \
    --profile "$profile" \
    --region "$region" \
    --filters Name=is-default,Values=true \
    --query 'Vpcs[0].VpcId' \
    --output text)"

  [[ -n "$vpc_id" && "$vpc_id" != "None" ]] || fail "No default VPC found. Re-run with --vpc-id and --subnet-id for a public subnet."
fi

if [[ -z "$subnet_id" ]]; then
  subnet_id="$(aws ec2 describe-subnets \
    --profile "$profile" \
    --region "$region" \
    --filters Name=vpc-id,Values="$vpc_id" Name=default-for-az,Values=true \
    --query 'sort_by(Subnets,&AvailabilityZone)[0].SubnetId' \
    --output text)"

  [[ -n "$subnet_id" && "$subnet_id" != "None" ]] || fail "No default subnet found in $vpc_id. Re-run with --subnet-id for a public subnet."
fi

repo_root_path="$(repo_root)"
credentials_dir="$repo_root_path/.local"
credentials_file="$credentials_dir/${stack_name}-credentials.env"
sftp_password="$(openssl rand -base64 36 | tr -d '\r\n')"

mkdir -p "$credentials_dir"
chmod 700 "$credentials_dir" 2>/dev/null || true

cat >"$credentials_file" <<CREDENTIALS
SFTP_USERNAME=$sftp_username
SFTP_PASSWORD=$sftp_password
SFTP_REMOTE_PATH=/data
SFTP_PORT=22
CREDENTIALS
chmod 600 "$credentials_file" 2>/dev/null || true

printf 'Deploy AWS SFTP testbed stack\n'
printf '\n'
printf 'This command creates or updates AWS runtime resources.\n'
printf 'Do not commit generated credentials, stack outputs, profile names, or AWS command output.\n'
printf '\n'
printf 'Deployment settings:\n'
printf '  Stack name: %s\n' "$stack_name"
printf '  Project name: %s\n' "$project_name"
printf '  Region: %s\n' "$region"
printf '  Instance type: %s\n' "$instance_type"
printf '  VPC ID: %s\n' "$vpc_id"
printf '  Subnet ID: %s\n' "$subnet_id"
printf '  Allowed CIDR: %s\n' "$allowed_cidr"
printf '  Public CIDR override: %s\n' "$allow_public_cidr"
printf '  SFTP username: %s\n' "$sftp_username"
printf '  Parameter name: %s\n' "$parameter_name"
printf '  Parameter update: %s\n' "$([[ "$skip_parameter_update" == "true" ]] && printf 'skipped' || printf 'enabled')"
printf '  Credentials file: .local/%s-credentials.env\n' "$stack_name"
if [[ "$show_sensitive" == "true" ]]; then
  printf '  SFTP password: %s\n' "$sftp_password"
else
  printf '  SFTP password: <redacted; use --show-sensitive only when needed>\n'
fi
printf '\n'

cd "$repo_root_path"

aws cloudformation deploy \
  --profile "$profile" \
  --region "$region" \
  --stack-name "$stack_name" \
  --template-file infra/cloudformation/template.yaml \
  --parameter-overrides \
    "AllowedCidr=$allowed_cidr" \
    "AllowPublicCidr=$allow_public_cidr" \
    "InstanceType=$instance_type" \
    "VpcId=$vpc_id" \
    "SubnetId=$subnet_id" \
    "ProjectName=$project_name" \
    "SftpUsername=$sftp_username" \
    "SftpPassword=$sftp_password" \
  --tags \
    "Project=$project_name" \
    "ManagedBy=aws-sftp-testbed" \
  --no-fail-on-empty-changeset

printf '\n'
printf 'Stack outputs:\n'
aws cloudformation describe-stacks \
  --profile "$profile" \
  --region "$region" \
  --stack-name "$stack_name" \
  --query 'Stacks[0].Outputs[].{Key:OutputKey,Value:OutputValue}' \
  --output table

if [[ "$skip_parameter_update" != "true" ]]; then
  printf '\nRefreshing SSM Parameter Store connection parameter...\n'
  "$script_dir/update-parameter.sh" \
    --profile "$profile" \
    --region "$region" \
    --stack-name "$stack_name" \
    --parameter-name "$parameter_name"
fi

printf '\n'
printf 'Deploy complete. Use destroy.sh for full runtime teardown when testing is complete.\n'
