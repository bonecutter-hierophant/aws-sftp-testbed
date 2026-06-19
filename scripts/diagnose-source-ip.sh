#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

profile="${AWS_SFTP_SERVER_PROFILE:-aws-sftp-server-operator}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
stack_name="aws-sftp-server"
lookback_minutes="15"

usage() {
  cat <<'USAGE'
Usage:
  scripts/diagnose-source-ip.sh [options]

Read recent sshd journal entries through SSM Run Command to identify the source
IP AWS/the server sees for SFTP login attempts. Requires the stack to be
temporarily enabled with diagnostics:enable.

Options:
  --profile <profile>       AWS CLI profile. Defaults to AWS_SFTP_SERVER_PROFILE
                            or aws-sftp-server-operator.
  --region <region>         AWS region. Defaults to AWS_REGION, AWS_DEFAULT_REGION,
                            or us-west-1.
  --stack-name <name>       CloudFormation stack name. Defaults to aws-sftp-server.
  --lookback-minutes <n>    Recent journal window. Defaults to 15.
  -h, --help                Show this help.

Do not commit command output. It may contain live IP addresses.
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
    --lookback-minutes)
      [[ $# -ge 2 ]] || fail "--lookback-minutes requires a value."
      lookback_minutes="$2"
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

require_command aws
validate_bootstrap_name "$stack_name" "stack name"
validate_positive_integer "$lookback_minutes" "lookback minutes"

instance_id="$(stack_instance_id "$profile" "$region" "$stack_name")"
[[ -n "$instance_id" && "$instance_id" != "None" ]] || fail "Unable to find instance ID from stack outputs."

ping_status="$(aws ssm describe-instance-information \
  --profile "$profile" \
  --region "$region" \
  --filters "Key=InstanceIds,Values=$instance_id" \
  --query 'InstanceInformationList[0].PingStatus' \
  --output text)"

[[ "$ping_status" == "Online" ]] || fail "SSM diagnostics are not online for $instance_id. Run diagnostics:enable, then wait a minute."

diagnostic_tmp_dir="$(repo_root)/.local"
mkdir -p "$diagnostic_tmp_dir"
command_file="$(mktemp "$diagnostic_tmp_dir/diagnose-source-ip-command.XXXXXX")"
parameters_file="$(mktemp "$diagnostic_tmp_dir/diagnose-source-ip-parameters.XXXXXX")"
trap 'rm -f "$command_file" "$parameters_file"' EXIT

cat >"$command_file" <<COMMAND
set -euo pipefail
echo "Recent unique source IPs from sshd journal:"
sudo journalctl -u sshd --since "-${lookback_minutes} minutes" --no-pager |
  grep -E "sshd.*(Accepted|Failed|Connection|Disconnected|Invalid)" |
  grep -Eo "from ([0-9]{1,3}\\.){3}[0-9]{1,3}" |
  cut -d " " -f 2 |
  sort -u || true
echo
echo "Recent sshd journal lines:"
sudo journalctl -u sshd --since "-${lookback_minutes} minutes" --no-pager |
  grep -E "sshd.*(Accepted|Failed|Connection|Disconnected|Invalid)" || true
COMMAND

node_command_file="$command_file"
node_parameters_file="$parameters_file"
aws_parameters_file="$parameters_file"
if command -v cygpath >/dev/null 2>&1; then
  node_command_file="$(cygpath -w "$command_file")"
  node_parameters_file="$(cygpath -w "$parameters_file")"
  aws_parameters_file="$(cygpath -w "$parameters_file")"
fi

node -e '
const fs = require("node:fs");
const commandPath = process.argv[1];
const outputPath = process.argv[2];
const command = fs.readFileSync(commandPath, "utf8");
fs.writeFileSync(outputPath, JSON.stringify({ commands: [command] }));
' "$node_command_file" "$node_parameters_file"

command_id="$(aws ssm send-command \
  --profile "$profile" \
  --region "$region" \
  --instance-ids "$instance_id" \
  --document-name AWS-RunShellScript \
  --comment "aws-sftp-testbed source IP diagnostics" \
  --parameters "file://$aws_parameters_file" \
  --query 'Command.CommandId' \
  --output text)"

[[ -n "$command_id" && "$command_id" != "None" ]] || fail "AWS did not return an SSM command ID."

for attempt in {1..20}; do
  status="$(aws ssm get-command-invocation \
    --profile "$profile" \
    --region "$region" \
    --command-id "$command_id" \
    --instance-id "$instance_id" \
    --query 'Status' \
    --output text 2>/dev/null || true)"

  if [[ "$status" == "Success" || "$status" == "Failed" || "$status" == "Cancelled" || "$status" == "TimedOut" ]]; then
    break
  fi

  sleep 2
done

aws ssm get-command-invocation \
  --profile "$profile" \
  --region "$region" \
  --command-id "$command_id" \
  --instance-id "$instance_id" \
  --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
  --output json
