#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/sing-box}"
CONFIG_PATH="${CONFIG_PATH:-$CONFIG_DIR/config.json}"
STATE_PATH="${STATE_PATH:-$CONFIG_DIR/manager.json}"
SERVICE_NAME="${SERVICE_NAME:-sing-box}"
SCRIPT_INSTALL_DIR="${SCRIPT_INSTALL_DIR:-/usr/local/sbin}"
LIB_INSTALL_DIR="${LIB_INSTALL_DIR:-/usr/local/lib/singbox-manager}"

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Запусти от root: $0 $*"
    exit 1
  fi
}

require_cmds() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if ((${#missing[@]} > 0)); then
    echo "Не хватает команд: ${missing[*]}"
    exit 1
  fi
}

require_state() {
  if [[ ! -f "$STATE_PATH" ]]; then
    echo "Не найден state-файл: $STATE_PATH"
    echo "Сначала запусти install.sh"
    exit 1
  fi
}

validate_client_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[A-Za-z0-9._@-]+$ ]]; then
    echo "Имя клиента должно соответствовать regex: [A-Za-z0-9._@-]+"
    exit 1
  fi
}

render_config() {
  require_cmds jq
  jq -n --slurpfile state "$STATE_PATH" '
    ($state[0]) as $s
    | {
        log: {
          level: "warn"
        },
        inbounds: [
          {
            type: "vless",
            tag: "vless-in",
            listen: $s.listen,
            listen_port: $s.server_port,
            users: (
              $s.clients
              | map({
                  name: .name,
                  uuid: .uuid,
                  flow: "xtls-rprx-vision"
                })
            ),
            tls: {
              enabled: true,
              server_name: $s.reality_server_name,
              reality: {
                enabled: true,
                handshake: {
                  server: $s.reality_handshake_server,
                  server_port: $s.reality_handshake_port
                },
                private_key: $s.reality_private_key,
                short_id: [$s.reality_short_id]
              }
            }
          }
        ],
        outbounds: [
          {
            type: "direct",
            tag: "direct"
          },
          {
            type: "block",
            tag: "block"
          }
        ],
        route: {
          final: "direct"
        },
        experimental: {
          clash_api: {
            external_controller: $s.api_controller,
            secret: $s.api_secret
          }
        }
      }
  '
}

write_config() {
  require_cmds sing-box jq
  local tmp_config
  tmp_config="$(mktemp)"

  render_config >"$tmp_config"
  sing-box check -c "$tmp_config" >/dev/null
  install -m 600 "$tmp_config" "$CONFIG_PATH"
  rm -f "$tmp_config"
}

restart_service() {
  systemctl restart "$SERVICE_NAME"
}

ensure_service_enabled() {
  systemctl enable --now "$SERVICE_NAME"
}

client_exists() {
  local name="$1"
  jq -e --arg name "$name" '.clients[] | select(.name == $name)' "$STATE_PATH" >/dev/null
}

client_uuid() {
  local name="$1"
  jq -r --arg name "$name" '
    .clients[]
    | select(.name == $name)
    | .uuid
  ' "$STATE_PATH"
}

api_url() {
  jq -r '.api_controller' "$STATE_PATH"
}

api_secret() {
  jq -r '.api_secret' "$STATE_PATH"
}

api_get() {
  local path="$1"
  curl -fsS --max-time 5 \
    -H "Authorization: Bearer $(api_secret)" \
    "http://$(api_url)$path"
}

format_vless_host() {
  local host="$1"

  if [[ "$host" == \[*\] ]]; then
    printf '%s\n' "$host"
    return
  fi

  if [[ "$host" == *:* ]]; then
    printf '[%s]\n' "$host"
    return
  fi

  printf '%s\n' "$host"
}

build_vless_url() {
  local name="$1"
  local uuid host port sni pbk sid formatted_host

  uuid="$(client_uuid "$name")"
  host="$(jq -r '.server_host' "$STATE_PATH")"
  port="$(jq -r '.server_port' "$STATE_PATH")"
  sni="$(jq -r '.reality_server_name' "$STATE_PATH")"
  pbk="$(jq -r '.reality_public_key' "$STATE_PATH")"
  sid="$(jq -r '.reality_short_id' "$STATE_PATH")"
  formatted_host="$(format_vless_host "$host")"

  if [[ -z "$uuid" || "$uuid" == "null" ]]; then
    echo "Клиент '$name' не найден"
    exit 1
  fi

  printf 'vless://%s@%s:%s?type=tcp&security=reality&fp=chrome&pbk=%s&sid=%s&sni=%s&flow=xtls-rprx-vision#%s\n' \
    "$uuid" "$formatted_host" "$port" "$pbk" "$sid" "$sni" "$name"
}

format_bytes() {
  local value="${1:-0}"
  numfmt --to=iec --suffix=B --format="%.2f" "$value"
}

normalize_stats() {
  jq -c '
    def to_array:
      if type == "array" then .
      elif type == "object" and has("users") then .users
      elif type == "object" and has("data") then .data
      elif type == "object" and (to_entries | length > 0) and ((to_entries[0].value | type) == "object") then
        to_entries | map(.value + {name: (.value.name // .key)})
      else
        []
      end;

    def to_number_or_zero:
      if type == "number" then .
      elif type == "string" then tonumber? // 0
      else 0
      end;

    to_array
    | map({
        name: (.name // .user // .username // .email // .tag // .id // empty),
        upload: (
          .upload // .uplink // .up // .sent // .tx // .traffic.upload // .traffic.uplink // 0
        ) | to_number_or_zero,
        download: (
          .download // .downlink // .down // .recv // .rx // .traffic.download // .traffic.downlink // 0
        ) | to_number_or_zero
      })
    | map(select(.name != null and .name != ""))
  '
}
