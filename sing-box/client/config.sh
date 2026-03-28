#!/usr/bin/env bash
set -euo pipefail

# Можно переопределить:
#   1) через переменную окружения SINGBOX_DIR
#   2) вторым аргументом скрипта
SINGBOX_DIR="${SINGBOX_DIR:-/usr/local/etc/sing-box}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"vless://...\" [singbox_dir]" >&2
  exit 1
fi

VLESS_URL="$1"
if [[ $# -ge 2 ]]; then
  SINGBOX_DIR="$2"
fi

mkdir -p "$SINGBOX_DIR"

# ---- Парсим VLESS URL ----
# vless://UUID@HOST:PORT?encryption=...&flow=...&security=reality&pbk=...&sni=...&sid=...&fp=chrome#NAME

u="${VLESS_URL#vless://}"   # срезаем схему
u="${u%%#*}"                # убираем #name, если есть

user_host_port="${u%%\?*}"
query=""
if [[ "$u" == *"?"* ]]; then
  query="${u#*\?}"
fi

# user_host_port = UUID@host:port
id="${user_host_port%%@*}"
host_port="${user_host_port#*@}"

if [[ "$host_port" == \[*\]:* ]]; then
  address="${host_port%%]*}"
  address="${address#[}"
  port="${host_port##*:}"
else
  address="${host_port%:*}"
  port="${host_port##*:}"
fi

encryption=""
flow=""
security=""
serverName=""
publicKey=""
shortId=""
fingerprint=""

IFS='&' read -ra params <<< "${query:-}"
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

: "${encryption:=none}"
: "${security:=reality}"
: "${fingerprint:=chrome}"

# ---- Общий VLESS outbound для sing-box ----
vless_outbound=$(cat <<EOF
{
  "type": "vless",
  "tag": "proxy",
  "server": "$address",
  "server_port": $port,
  "uuid": "$id",
  "flow": "$flow",
  "packet_encoding": "xudp",
  "tls": {
    "enabled": true,
    "server_name": "$serverName",
    "utls": {
      "enabled": true,
      "fingerprint": "$fingerprint"
    },
    "reality": {
      "enabled": true,
      "public_key": "$publicKey",
      "short_id": "$shortId"
    }
  }
}
EOF
)

# =================== client-whitelist.json (без TUN) ===================
cat > "$SINGBOX_DIR/client-whitelist.json" <<EOF
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "local-in",
      "listen": "127.0.0.1",
      "listen_port": 10808
    },
    {
      "type": "socks",
      "tag": "socks-proxy-in",
      "listen": "127.0.0.1",
      "listen_port": 10809
    }
  ],
  "outbounds": [
    $vless_outbound,
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "direct",
    "auto_detect_interface": true,
    "rules": [
      {
        "inbound": "socks-proxy-in",
        "outbound": "proxy"
      },
      // WHITELIST-START
      { "outbound": "proxy", "domain_suffix": ["habr.com"] },
      { "outbound": "proxy", "domain_suffix": ["voice.discord.gg"] },
      { "outbound": "proxy", "domain_suffix": ["voice.discord.media"] },
      { "outbound": "proxy", "domain_suffix": ["rtc.discord.com"] },
      { "outbound": "proxy", "domain_suffix": ["discord-attachments-uploads-prd.storage.googleapis.com"] },
      { "outbound": "proxy", "domain_suffix": ["discord.media"] },
      { "outbound": "proxy", "domain_suffix": ["test.com"] },
      { "outbound": "proxy", "domain_suffix": ["openai.com"] },
      { "outbound": "proxy", "domain_suffix": ["chatgpt.com"] },
      { "outbound": "proxy", "domain_suffix": ["discordcdn.com"] },
      { "outbound": "proxy", "domain_suffix": ["discordapp.com"] },
      { "outbound": "proxy", "domain_suffix": ["discord.gg"] },
      { "outbound": "proxy", "domain_suffix": ["discord.com"] },
      { "outbound": "proxy", "domain_suffix": ["ggpht.com"] },
      { "outbound": "proxy", "domain_suffix": ["googlevideo.com"] },
      { "outbound": "proxy", "domain_suffix": ["ytimg.com"] },
      { "outbound": "proxy", "domain_suffix": ["youtu.be"] },
      { "outbound": "proxy", "domain_suffix": ["youtube.com"] }
      // WHITELIST-END
      ,
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ]
  }
}
EOF

# =================== client-all.json (без TUN) ===================
cat > "$SINGBOX_DIR/client-all.json" <<EOF
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "local-in",
      "listen": "127.0.0.1",
      "listen_port": 10808
    }
  ],
  "outbounds": [
    $vless_outbound,
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "proxy",
    "auto_detect_interface": true,
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ]
  }
}
EOF

# =================== client-tun.json (VPN-режим) ===================
cat > "$SINGBOX_DIR/client-tun.json" <<EOF
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "singbox0",
      "address": [
        "172.19.0.1/30"
      ],
      "mtu": 9000,
      "auto_route": true,
      "strict_route": true,
      "sniff": true,
      "stack": "system"
    },
    {
      "type": "mixed",
      "tag": "local-in",
      "listen": "127.0.0.1",
      "listen_port": 10808
    }
  ],
  "outbounds": [
    $vless_outbound,
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "proxy",
    "auto_detect_interface": true,
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ]
  }
}
EOF

chmod 644 \
  "$SINGBOX_DIR/client-whitelist.json" \
  "$SINGBOX_DIR/client-all.json" \
  "$SINGBOX_DIR/client-tun.json"

echo "Generated:"
echo "  $SINGBOX_DIR/client-whitelist.json"
echo "  $SINGBOX_DIR/client-all.json"
echo "  $SINGBOX_DIR/client-tun.json"
