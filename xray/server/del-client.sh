#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="/usr/local/etc/xray/config.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq не найден (pacman -S jq)."
  exit 1
fi

EMAIL="${1:-}"
if [[ -z "$EMAIL" ]]; then
  echo "Использование: $0 email"
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Конфиг $CONFIG_PATH не найден."
  exit 1
fi

# Находим индекс inbound'а vless+reality
IDX=$(jq '
  .inbounds
  | to_entries
  | map(select(.value.protocol == "vless" and .value.streamSettings.security == "reality"))
  | .[0].key
' "$CONFIG_PATH")

if [[ "$IDX" == "null" ]]; then
  echo "Не найден inbound с protocol=vless и security=reality."
  exit 1
fi

# Сколько таких email сейчас есть
EXIST_COUNT=$(jq --arg email "$EMAIL" --argjson idx "$IDX" '
  .inbounds[$idx].settings.clients
  | map(select(.email == $email))
  | length
' "$CONFIG_PATH")

if [[ "$EXIST_COUNT" -eq 0 ]]; then
  echo "Пользователь с email '$EMAIL' не найден в конфиге."
  exit 1
fi

TMP_CFG="$(mktemp)"

# Удаляем всех клиентов с таким email
jq --arg email "$EMAIL" --argjson idx "$IDX" '
  .inbounds[$idx].settings.clients |=
    map(select(.email != $email))
' "$CONFIG_PATH" >"$TMP_CFG"

sudo mv "$TMP_CFG" "$CONFIG_PATH"
chmod 644 "$CONFIG_PATH"

echo "[*] Удалено записей с email '$EMAIL': $EXIST_COUNT"
echo "Не забудь перезапустить Xray (если нужно):"
echo "  sudo systemctl restart xray"
