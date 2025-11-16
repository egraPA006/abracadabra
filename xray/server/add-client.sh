#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="/usr/local/etc/xray/config.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq не найден (pacman -S jq)."
  exit 1
fi

if ! command -v uuidgen >/dev/null 2>&1; then
  echo "uuidgen не найден (pacman -S util-linux)."
  exit 1
fi

if ! command -v xray >/dev/null 2>&1; then
  echo "xray не найден в PATH."
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

TMP_CFG="$(mktemp)"
UUID="$(uuidgen)"

# Находим индекс vless+reality inbound'а
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

# Добавляем клиента
jq --arg email "$EMAIL" --arg id "$UUID" --argjson idx "$IDX" '
  .inbounds[$idx].settings.clients += [
    { "email": $email, "flow": "xtls-rprx-vision", "id": $id }
  ]
' "$CONFIG_PATH" >"$TMP_CFG"

sudo mv "$TMP_CFG" "$CONFIG_PATH"
chmod 644 "$CONFIG_PATH"

# Достаём параметры для vless-ссылки
HOST=$(jq -r ".inbounds[$IDX].listen" "$CONFIG_PATH")
PORT=$(jq -r ".inbounds[$IDX].port" "$CONFIG_PATH")
FLOW="xtls-rprx-vision"
NETWORK="tcp"

TARGET=$(jq -r ".inbounds[$IDX].streamSettings.realitySettings.target" "$CONFIG_PATH")
SNI=$(jq -r ".inbounds[$IDX].streamSettings.realitySettings.serverNames[0]" "$CONFIG_PATH")
SID=$(jq -r ".inbounds[$IDX].streamSettings.realitySettings.shortIds[0]" "$CONFIG_PATH")

# PublicKey берём из meta, куда мы его положили при генерации конфига
PBK=$(jq -r ".meta.realityPublicKey" "$CONFIG_PATH")

if [[ -z "$PBK" || "$PBK" == "null" ]]; then
  # fallback: считаем из приватного
  PRIV=$(jq -r ".inbounds[$IDX].streamSettings.realitySettings.privateKey" "$CONFIG_PATH")
  PBK=$(xray x25519 -i "$PRIV" | awk '/Public key/ {print $3}')
fi

# fingerprint можно менять, но chrome самый безопасный дефолт
FP="chrome"

VLESS_URL="vless://${UUID}@${HOST}:${PORT}?type=${NETWORK}&security=reality&fp=${FP}&pbk=${PBK}&sid=${SID}&sni=${SNI}&flow=${FLOW}#${EMAIL}"

echo "[*] Добавлен клиент:"
echo "  email: ${EMAIL}"
echo "  uuid : ${UUID}"
echo
echo "vless ссылка:"
echo "${VLESS_URL}"
echo
echo "Не забудь перезапустить Xray (если нужно):"
echo "  sudo systemctl restart xray@server"
