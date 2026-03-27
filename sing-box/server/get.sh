#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  source "$SCRIPT_DIR/common.sh"
else
  source /usr/local/lib/singbox-manager/common.sh
fi

NAME="${1:-}"

require_root
require_state
require_cmds jq

if [[ -z "$NAME" ]]; then
  echo "Использование: $0 CLIENT_NAME"
  exit 1
fi

if ! client_exists "$NAME"; then
  echo "Клиент '$NAME' не найден"
  exit 1
fi

build_vless_url "$NAME"
