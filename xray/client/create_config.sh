#!/usr/bin/env bash
set -euo pipefail

# Можно переопределить:
#   1) через переменную окружения XRAY_DIR
#   2) вторым аргументом скрипта
XRAY_DIR="${XRAY_DIR:-/usr/local/etc/xray}"
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"vless://...\" [xray_dir]" >&2
  exit 1
fi

VLESS_URL="$1"
if [[ $# -ge 2 ]]; then
  XRAY_DIR="$2"
fi

mkdir -p "$XRAY_DIR"

# ---- Парсим VLESS URL ----
# Ожидается что-то вида:
# vless://UUID@HOST:PORT?encryption=...&flow=...&security=reality&pbk=...&sni=...&sid=...&fp=chrome#NAME

# убираем схему
u="${VLESS_URL#vless://}"
# отбрасываем #name, если есть
u="${u%%#*}"

# отделяем часть до ? и query
user_host_port="${u%%\?*}"
query=""
if [[ "$u" == *"?"* ]]; then
  query="${u#*\?}"
fi

# user_host_port = UUID@host:port
id="${user_host_port%%@*}"
host_port="${user_host_port#*@}"
address="${host_port%%:*}"
port="${host_port##*:}"

encryption=""
flow=""
security=""
serverName=""
publicKey=""
shortId=""
fingerprint=""

IFS='&' read -ra params <<< "$query"
for kv in "${params[@]:-}"; do
  key="${kv%%=*}"
  val="${kv#*=}"
  case "$key" in
    encryption) encryption="$val" ;;
    flow)       flow="$val" ;;
    security)   security="$val" ;;
    sni)        serverName="$val" ;;
    pbk)        publicKey="$val" ;;
    sid)        shortId="$val" ;;
    fp)         fingerprint="$val" ;;
  esac
done

# значения по умолчанию, если чего-то нет
: "${encryption:=none}"
: "${security:=reality}"
: "${fingerprint:=chrome}"

# ---- Генерация client-whitelist.json ----
cat > "$XRAY_DIR/client-whitelist.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "transparent-in",
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "mixed",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": false,
        "routeOnly": false,
        "destOverride": []
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$address",
            "port": $port,
            "users": [
              {
                "id": "$id",
                "encryption": "$encryption",
                "flow": "$flow"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "$security",
        "realitySettings": {
          "serverName": "$serverName",
          "publicKey": "$publicKey",
          "shortId": "$shortId",
          "fingerprint": "$fingerprint",
          "show": false
        }
      }
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      // WHITELIST-START
      {"type":"field","domain":["domain:habr.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:voice.discord.gg"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:voice.discord.media"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:rtc.discord.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discord-attachments-uploads-prd.storage.googleapis.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discord.media"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:test.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:openai.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:chatgpt.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discordcdn.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discordapp.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discord.gg"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:discord.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:ggpht.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:googlevideo.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:ytimg.com"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:youtu.be"],"outboundTag":"proxy"},
      {"type":"field","domain":["domain:youtube.com"],"outboundTag":"proxy"},
      // сюда будем добавлять правила вида:
      // { "type":"field","domain":["domain:example.com"],"outboundTag":"proxy" },
      // WHITELIST-END
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      }
      // всё остальное (если не матчится домен/локалка) → первый outbound = "direct"
    ]
  }
}
EOF

# ---- Генерация client-all.json ----
cat > "$XRAY_DIR/client-all.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "transparent-in",
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "mixed",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": false,
        "routeOnly": false,
        "destOverride": []
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$address",
            "port": $port,
            "users": [
              {
                "id": "$id",
                "encryption": "$encryption",
                "flow": "$flow"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "$security",
        "realitySettings": {
          "serverName": "$serverName",
          "publicKey": "$publicKey",
          "shortId": "$shortId",
          "fingerprint": "$fingerprint",
          "show": false
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
sudo chmod 644 "$XRAY_DIR/client-whitelist.json" "$XRAY_DIR/client-all.json"
echo "Generated:"
echo "  $XRAY_DIR/client-whitelist.json"
echo "  $XRAY_DIR/client-all.json"
