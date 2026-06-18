#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$script_dir/../lib/common.sh"

bootstrap_selected="false"
approved_permission_set="false"
permission_set_name="AwsSftpServer-Operator"
project_name="aws-sftp-server"
sso_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
session_duration="PT4H"
instance_arn=""
aws_args=()

usage() {
  cat <<'USAGE'
Usage:
  scripts/bootstrap/ensure-permission-set.sh --bootstrap --approve-permission-set [options]

Create or update the IAM Identity Center permission set used for routine
SFTP server operation. This command contacts AWS and changes durable IAM
Identity Center configuration.

Required:
  --bootstrap                  Explicitly select the high-privilege bootstrap lane.
  --approve-permission-set     Approve this bounded permission set phase.

Options:
  --permission-set-name <name> Permission set name. Defaults to AwsSftpServer-Operator.
  --project-name <name>        Project resource prefix. Defaults to aws-sftp-server.
  --sso-region <region>        IAM Identity Center region. Defaults to AWS_REGION,
                               AWS_DEFAULT_REGION, or us-west-1.
  --instance-arn <arn>         IAM Identity Center instance ARN. Required only if
                               more than one instance is visible.
  --session-duration <value>   ISO-8601 session duration. Defaults to PT4H.
  --profile <profile>          AWS CLI profile to use. Prefer local-only profile names.
  -h, --help                   Show this help.

Do not commit account IDs, ARNs, profile names, or command output.
USAGE
}

find_permission_set_arn() {
  local target_instance_arn="$1"
  local target_name="$2"
  local candidate_arn
  local candidate_name

  while read -r candidate_arn; do
    [[ -n "$candidate_arn" ]] || continue
    candidate_name="$(aws "${aws_args[@]}" sso-admin describe-permission-set \
      --region "$sso_region" \
      --instance-arn "$target_instance_arn" \
      --permission-set-arn "$candidate_arn" \
      --query 'PermissionSet.Name' \
      --output text)"

    if [[ "$candidate_name" == "$target_name" ]]; then
      printf '%s\n' "$candidate_arn"
      return 0
    fi
  done < <(aws "${aws_args[@]}" sso-admin list-permission-sets \
    --region "$sso_region" \
    --instance-arn "$target_instance_arn" \
    --query 'PermissionSets[]' \
    --output text | tr '\t' '\n' | sed '/^$/d')
}

write_inline_policy() {
  local output_path="$1"
  local prefix="$2"

  cat >"$output_path" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFormationProjectStacks",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CancelUpdateStack",
        "cloudformation:ContinueUpdateRollback",
        "cloudformation:CreateChangeSet",
        "cloudformation:CreateStack",
        "cloudformation:DeleteChangeSet",
        "cloudformation:DeleteStack",
        "cloudformation:Describe*",
        "cloudformation:DetectStackDrift",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:GetTemplate",
        "cloudformation:GetTemplateSummary",
        "cloudformation:List*",
        "cloudformation:UpdateStack",
        "cloudformation:ValidateTemplate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Ec2ProjectRuntime",
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:DeleteSecurityGroup",
        "ec2:Describe*",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RunInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IamProjectInstanceProfile",
      "Effect": "Allow",
      "Action": [
        "iam:AddRoleToInstanceProfile",
        "iam:AttachRolePolicy",
        "iam:CreateInstanceProfile",
        "iam:CreateRole",
        "iam:DeleteInstanceProfile",
        "iam:DeleteRole",
        "iam:DeleteRolePolicy",
        "iam:GetInstanceProfile",
        "iam:GetRole",
        "iam:ListAttachedRolePolicies",
        "iam:ListInstanceProfiles",
        "iam:ListRolePolicies",
        "iam:PassRole",
        "iam:PutRolePolicy",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile",
        "iam:TagRole"
      ],
      "Resource": [
        "arn:aws:iam::*:instance-profile/${prefix}-*",
        "arn:aws:iam::*:role/${prefix}-*"
      ]
    },
    {
      "Sid": "SecretsManagerProjectSecrets",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:TagResource",
        "secretsmanager:UpdateSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:${prefix}*"
    },
    {
      "Sid": "ReadAmazonLinuxPublicAmiParameter",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"
    },
    {
      "Sid": "CallerAndRegionDiscovery",
      "Effect": "Allow",
      "Action": [
        "account:GetContactInformation",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap)
      bootstrap_selected="true"
      shift
      ;;
    --approve-permission-set)
      approved_permission_set="true"
      shift
      ;;
    --permission-set-name)
      [[ $# -ge 2 ]] || fail "--permission-set-name requires a value."
      permission_set_name="$2"
      shift 2
      ;;
    --project-name)
      [[ $# -ge 2 ]] || fail "--project-name requires a value."
      project_name="$2"
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
    --session-duration)
      [[ $# -ge 2 ]] || fail "--session-duration requires a value."
      session_duration="$2"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || fail "--profile requires a value."
      aws_args+=(--profile "$2")
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
validate_bootstrap_name "$permission_set_name" "permission set name"
validate_bootstrap_name "$project_name" "project name"

if [[ "$approved_permission_set" != "true" ]]; then
  fail "Refusing permission set changes without --approve-permission-set."
fi

printf 'Bootstrap permission set: IAM Identity Center routine operator access\n'
printf '\n'
printf 'This command creates or updates durable IAM Identity Center configuration.\n'
printf 'Do not commit command output, account IDs, ARNs, or profile names.\n'
printf '\n'
printf 'Planned phase:\n'
printf '  Permission set name: %s\n' "$permission_set_name"
printf '  Project resource prefix: %s\n' "$project_name"
printf '  Session duration: %s\n' "$session_duration"
printf '  IAM Identity Center region: %s\n' "$sso_region"
printf '\n'

if [[ -z "$instance_arn" ]]; then
  mapfile -t instance_arns < <(aws "${aws_args[@]}" sso-admin list-instances \
    --region "$sso_region" \
    --query 'Instances[].InstanceArn' \
    --output text | tr '\t' '\n' | sed '/^$/d')

  if [[ "${#instance_arns[@]}" -eq 0 ]]; then
    fail "No IAM Identity Center instances found in $sso_region."
  fi

  if [[ "${#instance_arns[@]}" -gt 1 ]]; then
    fail "Multiple IAM Identity Center instances found. Re-run with --instance-arn."
  fi

  instance_arn="${instance_arns[0]}"
fi

permission_set_arn="$(find_permission_set_arn "$instance_arn" "$permission_set_name")"

if [[ -z "$permission_set_arn" ]]; then
  printf 'Creating permission set...\n'
  permission_set_arn="$(aws "${aws_args[@]}" sso-admin create-permission-set \
    --region "$sso_region" \
    --instance-arn "$instance_arn" \
    --name "$permission_set_name" \
    --description "Routine operator access for disposable SFTP server resources." \
    --session-duration "$session_duration" \
    --query 'PermissionSet.PermissionSetArn' \
    --output text)"
else
  printf 'Updating existing permission set...\n'
  aws "${aws_args[@]}" sso-admin update-permission-set \
    --region "$sso_region" \
    --instance-arn "$instance_arn" \
    --permission-set-arn "$permission_set_arn" \
    --description "Routine operator access for disposable SFTP server resources." \
    --session-duration "$session_duration"
fi

policy_file="$(mktemp)"
trap 'rm -f "$policy_file"' EXIT
write_inline_policy "$policy_file" "$project_name"
policy_document="$(<"$policy_file")"

printf 'Installing inline policy...\n'
aws "${aws_args[@]}" sso-admin put-inline-policy-to-permission-set \
  --region "$sso_region" \
  --instance-arn "$instance_arn" \
  --permission-set-arn "$permission_set_arn" \
  --inline-policy "$policy_document"

printf 'Permission set is ready: %s\n' "$permission_set_name"
printf 'Next phase: assign this permission set to the operator identity for the project account.\n'
