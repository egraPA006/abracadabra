#!/usr/bin/env bash
set -euo pipefail

# === НАСТРОЙКИ, ПРАВЬ ТОЛЬКО ЭТО ===

CONFIG_PATH="/usr/local/etc/xray/config.json"

# внешний IP или домен сервера (для ссылки и слушающего адреса)
SERVER_ADDR="1.2.3.4"

# порт Reality
SERVER_PORT=443

# сайт-маскировка (должен реально открываться по HTTPS)
REALITY_TARGET_DOMAIN="nltimes.nl"
REALITY_TARGET_PORT=443

# список serverNames (SNI), обычно тот же домен
REALITY_SERVERNAMES=("nltimes.nl" "www.nltimes.nl")

# начальные email'ы клиентов (можно оставить пустой массив)
INITIAL_USERS=("me")

# === Дальше трогать не обязательно ===

if ! command -v xray >/dev/null 2>&1; then
  echo "xray не найден в PATH. Установи xray-core."
  exit 1
fi

if ! command -v uuidgen >/dev/null 2>&1; then
  echo "uuidgen не найден (pacman -S util-linux)."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq не найден (pacman -S jq)."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl не найден (pacman -S openssl)."
  exit 1
fi

echo "[*] Генерирую Reality X25519 ключи..."
XRAY_KEYPAIR="$(xray x25519)"
PRIV_KEY="$(echo "$XRAY_KEYPAIR" | awk '/^PrivateKey:/ {print $2}')"
PUB_KEY="$(echo "$XRAY_KEYPAIR"  | awk '/^Password:/ {print $2}')"

echo "  Private: $PRIV_KEY"
echo "  Public : $PUB_KEY"

echo "[*] Генерирую shortIds..."
SHORTIDS=()
for i in {1..4}; do
  SHORTIDS+=("$(openssl rand -hex 4)")
done

# Собираем массивы для JSON
SERVERNAMES_JSON=$(printf '"%s",' "${REALITY_SERVERNAMES[@]}")
SERVERNAMES_JSON="[${SERVERNAMES_JSON%,}]"

SHORTIDS_JSON=$(printf '"%s",' "${SHORTIDS[@]}")
SHORTIDS_JSON="[${SHORTIDS_JSON%,}]"

# Генерим стартовых пользователей
CLIENTS_JSON="[]"
for EMAIL in "${INITIAL_USERS[@]}"; do
  UUID="$(uuidgen)"
  CLIENTS_JSON=$(echo "$CLIENTS_JSON" | jq --arg email "$EMAIL" --arg id "$UUID" \
    '. + [{email:$email, flow:"xtls-rprx-vision", id:$id}]')
done

# Строим конфиг
TMP_CFG="$(mktemp)"

cat >"$TMP_CFG" <<EOF
{
  "log": {
    "access": "",
    "dnsLog": false,
    "error": "",
    "loglevel": "warning",
    "maskAddress": ""
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "ip": ["geoip:private"],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": ["bittorrent"],
        "type": "field"
      }
    ]
  },
  "dns": null,
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "tunnel",
      "settings": { "address": "127.0.0.1" },
      "streamSettings": null,
      "tag": "api",
      "sniffing": null
    },
    {
      "listen": "${SERVER_ADDR}",
      "port": ${SERVER_PORT},
      "protocol": "vless",
      "settings": {
        "clients": ${CLIENTS_JSON},
        "decryption": "none",
        "encryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "realitySettings": {
          "privateKey": "${PRIV_KEY}",
          "serverNames": ${SERVERNAMES_JSON},
          "shortIds": ${SHORTIDS_JSON},
          "show": false,
          "target": "${REALITY_TARGET_DOMAIN}:${REALITY_TARGET_PORT}",
          "xver": 0
        },
        "security": "reality",
        "tcpSettings": {
          "acceptProxyProtocol": false,
          "header": { "type": "none" }
        }
      },
      "tag": "inbound-${SERVER_ADDR}:${SERVER_PORT}",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false,
        "routeOnly": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": { "domainStrategy": "AsIs", "noises": [], "redirect": "" },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "transport": null,
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true,
      "statsOutboundDownlink": false,
      "statsOutboundUplink": false
    }
  },
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "stats": {},
  "reverse": null,
  "fakedns": null,
  "observatory": null,
  "burstObservatory": null,
  "metrics": {
    "listen": "127.0.0.1:11111",
    "tag": "metrics_out"
  },
  "meta": {
    "realityPublicKey": "${PUB_KEY}"
  }
}
EOF

sudo mkdir -p "$(dirname "$CONFIG_PATH")"
sudo mv "$TMP_CFG" "$CONFIG_PATH"
chmod 644 "$CONFIG_PATH"
echo "[*] Конфиг записан в $CONFIG_PATH"
echo "[*] PublicKey Reality (pbk) для клиентов: $PUB_KEY"
echo
echo "Не забудь перезапустить сервис, например:"
echo "  sudo systemctl restart xray"
