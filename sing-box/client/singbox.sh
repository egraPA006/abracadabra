#!/usr/bin/env bash

# Sing-box + Reality control (bash)
# подключать в ~/.bashrc:
#   source /path/to/sing-box/client/singbox.sh

SINGBOX_DIR="${SINGBOX_DIR:-/usr/local/etc/sing-box}"

singbox-on() {
  local mode="${1:-all}"
  local cfg

  case "$mode" in
    all)
      cfg="$SINGBOX_DIR/client-all.json"
      ;;
    wl|whitelist)
      cfg="$SINGBOX_DIR/client-whitelist.json"
      ;;
    tun)
      cfg="$SINGBOX_DIR/client-tun.json"
      ;;
    *)
      echo "Usage: singbox-on [all|wl|tun]"
      echo "  all  - весь трафик (для приложений на 127.0.0.1:10808) через proxy, без TUN"
      echo "  wl   - только whitelist-домены через proxy, без TUN"
      echo "  tun  - полноценный VPN (TUN, весь трафик системы через proxy)"
      return 1
      ;;
  esac

  if [[ ! -f "$cfg" ]]; then
    echo "Config $cfg not found"
    return 1
  fi

  echo "Using config $cfg"
  sudo ln -sf "$cfg" "$SINGBOX_DIR/client.json"

  echo "Restarting sing-box@client..."
  sudo systemctl restart sing-box@client
}

singbox-off() {
  echo "Stopping sing-box@client..."
  sudo systemctl stop sing-box@client
}

singbox-stat() {
  systemctl status sing-box@client --no-pager
}

singbox-wl-list() {
  local wl_config="$SINGBOX_DIR/client-whitelist.json"

  if [[ ! -f "$wl_config" ]]; then
    echo "No $wl_config found"
    return 1
  fi

  sudo sed -n '/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/{
    s/.*"domain_suffix":[[:space:]]*\["\([^"]*\)".*/\1/p
  }' "$wl_config"
}

singbox-wl-add() {
  local domain="${1:-}"
  local wl_config="$SINGBOX_DIR/client-whitelist.json"
  local tmp_file

  if [[ -z "$domain" ]]; then
    echo "Usage: singbox-wl-add example.com"
    return 1
  fi

  if [[ ! -f "$wl_config" ]]; then
    echo "Whitelist config $wl_config not found"
    return 1
  fi

  if singbox-wl-list | grep -qx "$domain"; then
    echo "$domain already in whitelist"
    return 0
  fi

  tmp_file="$(mktemp)"
  sudo awk -v dom="$domain" '
    /\/\/ WHITELIST-START/ {
      print
      print "      { \"outbound\": \"proxy\", \"domain_suffix\": [\"" dom "\"] },"
      next
    }
    { print }
  ' "$wl_config" >"$tmp_file"

  sudo mv "$tmp_file" "$wl_config"
  sudo chmod 644 "$wl_config"
  echo "Added $domain to whitelist"
}

singbox-wl-del() {
  local domain="${1:-}"
  local wl_config="$SINGBOX_DIR/client-whitelist.json"

  if [[ -z "$domain" ]]; then
    echo "Usage: singbox-wl-del example.com"
    return 1
  fi

  if [[ ! -f "$wl_config" ]]; then
    echo "Whitelist config $wl_config not found"
    return 1
  fi

  sudo sed -i "/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/ { /\"domain_suffix\":[[:space:]]*\[\"$domain\"/d }" "$wl_config"
  echo "Removed $domain from whitelist (if existed)"
}
