# =====================================================================
# XRAY + REALITY CONTROL (BASH) — ПУТЬ В ОДНОЙ ПЕРЕМЕННОЙ
# =====================================================================

# <<< УСТАНОВИ ЗДЕСЬ СВОЙ ПУТЬ К КОНФИГАМ XRAY >>>
XRAY_DIR="/etc/xray"
# Например, на macOS:
# XRAY_DIR="/usr/local/etc/xray"
# XRAY_DIR="$HOME/xray"

xray_on() { # start xray with mode: all or wl
    local mode cfg
    mode="$1"
    if [ -z "$mode" ]; then
        mode="all"
    fi

    case "$mode" in
        all)
            cfg="$XRAY_DIR/client-all.json"
            ;;
        wl|whitelist)
            cfg="$XRAY_DIR/client-whitelist.json"
            ;;
        *)
            echo "Usage: xray-on [all|wl]"
            return 1
            ;;
    esac

    if [ ! -f "$cfg" ]; then
        echo "Config $cfg not found"
        return 1
    fi

    echo "Using config $cfg"
    sudo ln -sf "$cfg" "$XRAY_DIR/client.json"

    echo "Restarting xray@client..."
    sudo systemctl restart xray@client
}

xray_off() {
    echo "Stopping xray@client..."
    sudo systemctl stop xray@client
}

xray_stat() {
    systemctl status xray@client --no-pager
}

# ----------------------- WHITELIST MANAGEMENT ------------------------

xray_wl_list() {
    local cfg="$XRAY_DIR/client-whitelist.json"

    if [ ! -f "$cfg" ]; then
        echo "No $cfg"
        return 1
    fi

    sudo sed -n '/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/{
        s/.*"domain:\([^"]*\)".*/\1/p
    }' "$cfg"
}

xray_wl_add() {
    local d tmp cfg="$XRAY_DIR/client-whitelist.json"
    d="$1"

    if [ -z "$d" ]; then
        echo "Usage: xray-wl-add example.com"
        return 1
    fi

    if xray_wl_list | grep -qx "$d"; then
        echo "$d already in whitelist"
        return 0
    fi

    tmp="$(mktemp)"

    sudo awk -v dom="$d" '
        /\/\/ WHITELIST-START/ {
            print
            print "      {\"type\":\"field\",\"domain\":[\"domain:" dom "\"],\"outboundTag\":\"proxy\"},"
            next
        }
        { print }
    ' "$cfg" > "$tmp"

    sudo mv "$tmp" "$cfg"
    sudo chmod 644 "$cfg"
    echo "Added $d to whitelist"
}

xray_wl_del() {
    local d cfg="$XRAY_DIR/client-whitelist.json"
    d="$1"

    if [ -z "$d" ]; then
        echo "Usage: xray-wl-del example.com"
        return 1
    fi

    sudo sed -i "/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/ { /\"domain:$d\"/d }" "$cfg"
    echo "Removed $d (if existed)"
}

# --------------------------- ALIASES ----------------------------------

alias xray-on='xray_on'
alias xray-off='xray_off'
alias xray-stat='xray_stat'

alias xray-wl-list='xray_wl_list'
alias xray-wl-add='xray_wl_add'
alias xray-wl-del='xray_wl_del'
