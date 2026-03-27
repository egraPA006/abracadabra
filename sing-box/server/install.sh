#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  source "$SCRIPT_DIR/common.sh"
else
  source /usr/local/lib/singbox-manager/common.sh
fi

SERVER_HOST="${SERVER_HOST:-}"
LISTEN_ADDR="${LISTEN_ADDR:-::}"
SERVER_PORT="${SERVER_PORT:-443}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_HANDSHAKE_SERVER="${REALITY_HANDSHAKE_SERVER:-www.cloudflare.com}"
REALITY_HANDSHAKE_PORT="${REALITY_HANDSHAKE_PORT:-443}"
INITIAL_CLIENT="${INITIAL_CLIENT:-}"

require_root
require_cmds bash curl awk sed grep cut install systemctl

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl jq uuid-runtime coreutils bsdextrautils

if ! command -v sing-box >/dev/null 2>&1; then
  curl -fsSL https://sing-box.app/install.sh | sh
fi

require_cmds sing-box jq uuidgen numfmt

if [[ -z "$SERVER_HOST" ]]; then
  SERVER_HOST="$(curl -4fsS https://api.ipify.org || true)"
fi

if [[ -z "$SERVER_HOST" ]]; then
  SERVER_HOST="$(hostname -I | awk '{print $1}')"
fi

if [[ -z "$SERVER_HOST" ]]; then
  echo "Не удалось определить SERVER_HOST автоматически."
  echo "Запусти так: SERVER_HOST=your.domain.or.ip $0"
  exit 1
fi

mkdir -p "$CONFIG_DIR" "$LIB_INSTALL_DIR" "$SCRIPT_INSTALL_DIR"
chmod 700 "$CONFIG_DIR"

keypair="$(sing-box generate reality-keypair)"
reality_private_key="$(awk '/PrivateKey:/ {print $2}' <<<"$keypair")"
reality_public_key="$(awk '/PublicKey:/ {print $2}' <<<"$keypair")"
reality_short_id="$(sing-box generate rand 4 --hex)"
clash_secret="$(sing-box generate rand 16 --hex)"

clients='[]'
if [[ -n "$INITIAL_CLIENT" ]]; then
  validate_client_name "$INITIAL_CLIENT"
  clients="$(jq -n --arg name "$INITIAL_CLIENT" --arg uuid "$(uuidgen)" '
    [
      {
        name: $name,
        uuid: $uuid,
        created_at: (now | todateiso8601)
      }
    ]
  ')"
fi

jq -n \
  --arg listen "$LISTEN_ADDR" \
  --arg server_host "$SERVER_HOST" \
  --argjson server_port "$SERVER_PORT" \
  --arg reality_server_name "$REALITY_SERVER_NAME" \
  --arg reality_handshake_server "$REALITY_HANDSHAKE_SERVER" \
  --argjson reality_handshake_port "$REALITY_HANDSHAKE_PORT" \
  --arg reality_private_key "$reality_private_key" \
  --arg reality_public_key "$reality_public_key" \
  --arg reality_short_id "$reality_short_id" \
  --arg api_controller "127.0.0.1:9090" \
  --arg api_secret "$clash_secret" \
  --argjson clients "$clients" \
  '{
    listen: $listen,
    server_host: $server_host,
    server_port: $server_port,
    reality_server_name: $reality_server_name,
    reality_handshake_server: $reality_handshake_server,
    reality_handshake_port: $reality_handshake_port,
    reality_private_key: $reality_private_key,
    reality_public_key: $reality_public_key,
    reality_short_id: $reality_short_id,
    api_controller: $api_controller,
    api_secret: $api_secret,
    clients: $clients
  }' >"$STATE_PATH"

chmod 600 "$STATE_PATH"
write_config

if [[ -f "$SCRIPT_DIR/common.sh" && -f "$SCRIPT_DIR/add.sh" ]]; then
  install -m 644 "$SCRIPT_DIR/common.sh" "$LIB_INSTALL_DIR/common.sh"
  install -m 755 "$SCRIPT_DIR/install.sh" "$SCRIPT_INSTALL_DIR/singbox-install"
  install -m 755 "$SCRIPT_DIR/add.sh" "$SCRIPT_INSTALL_DIR/singbox-add"
  install -m 755 "$SCRIPT_DIR/del.sh" "$SCRIPT_INSTALL_DIR/singbox-del"
  install -m 755 "$SCRIPT_DIR/list.sh" "$SCRIPT_INSTALL_DIR/singbox-list"
  install -m 755 "$SCRIPT_DIR/get.sh" "$SCRIPT_INSTALL_DIR/singbox-get"
fi

cat > /etc/systemd/system/"$SERVICE_NAME".service <<EOF
[Unit]
Description=sing-box server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$(command -v sing-box) run -c $CONFIG_PATH
Restart=on-failure
RestartSec=3
User=root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
ensure_service_enabled

echo "Установлено."
echo "Конфиг: $CONFIG_PATH"
echo "State:  $STATE_PATH"
echo "Сервис: systemctl status $SERVICE_NAME --no-pager"
echo "Public key: $reality_public_key"
echo "Short ID:   $reality_short_id"
echo
echo "Команды управления:"
echo "  singbox-add NAME"
echo "  singbox-del NAME"
echo "  singbox-list"
echo "  singbox-get NAME"
echo
echo "Пример:"
echo "  singbox-add phone"
echo "  singbox-get phone"
echo
if [[ -n "$INITIAL_CLIENT" ]]; then
  echo "Ссылка для $INITIAL_CLIENT:"
  build_vless_url "$INITIAL_CLIENT"
fi
