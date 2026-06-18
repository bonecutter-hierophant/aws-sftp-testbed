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
sftp_username="sftpuser"
allowed_cidr=""
allow_public_cidr="false"
show_sensitive="false"

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
  --sftp-username <name>       SFTP username. Defaults to sftpuser.
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
    --sftp-username)
      [[ $# -ge 2 ]] || fail "--sftp-username requires a value."
      sftp_username="$2"
      shift 2
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
printf '  Allowed CIDR: %s\n' "$allowed_cidr"
printf '  Public CIDR override: %s\n' "$allow_public_cidr"
printf '  SFTP username: %s\n' "$sftp_username"
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

printf '\n'
printf 'Deploy complete. Use destroy.sh for full runtime teardown when testing is complete.\n'
