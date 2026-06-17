#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

printf '%s\n' "Instance stopped. EC2 instance usage charges should stop, but attached EBS volumes and some other resources may still incur charges. Use destroy.sh for full teardown."
not_implemented "stop.sh"
