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
require_cmds jq sing-box

if [[ -z "$NAME" ]]; then
  echo "Использование: $0 CLIENT_NAME"
  exit 1
fi

validate_client_name "$NAME"

if ! client_exists "$NAME"; then
  echo "Клиент '$NAME' не найден"
  exit 1
fi

tmp_state="$(mktemp)"
jq --arg name "$NAME" '
  .clients |= map(select(.name != $name))
' "$STATE_PATH" >"$tmp_state"

install -m 600 "$tmp_state" "$STATE_PATH"
rm -f "$tmp_state"

write_config
restart_service

echo "Клиент '$NAME' удалён"

