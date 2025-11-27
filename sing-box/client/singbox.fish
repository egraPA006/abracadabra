# Sing-box + Reality control (fish)
# кладёшь в ~/.config/fish/conf.d/singbox.fish

set -g SINGBOX_DIR "/usr/local/etc/sing-box"

function singbox-on --description "start sing-box with mode: all|wl|tun"
    set mode $argv[1]
    if test -z "$mode"
        set mode "all"
    end

    switch "$mode"
        case all
            # all: всё, что ходит через 127.0.0.1:10808, идёт в proxy, без TUN
            set cfg "$SINGBOX_DIR/client-all.json"
        case wl whitelist
            # wl: через proxy только домены из whitelist, без TUN
            set cfg "$SINGBOX_DIR/client-whitelist.json"
        case tun
            # tun: VPN-режим, TUN+auto_route, весь системный трафик через proxy (кроме локалок)
            set cfg "$SINGBOX_DIR/client-tun.json"
        case '*'
            echo "Usage: singbox-on [all|wl|tun]"
            echo "  all  - весь трафик (для приложений на 127.0.0.1:10808) через proxy, без TUN"
            echo "  wl   - только whitelist-домены через proxy, без TUN"
            echo "  tun  - полноценный VPN (TUN, весь трафик системы через proxy)"
            return 1
    end

    if not test -f "$cfg"
        echo "Config $cfg not found"
        return 1
    end

    echo "Using config $cfg"
    # sing-box@client читает /usr/local/etc/sing-box/client.json
    sudo ln -sf "$cfg" "$SINGBOX_DIR/client.json"

    echo "Restarting sing-box@client..."
    sudo systemctl restart sing-box@client
end

function singbox-off --description "stop sing-box"
    echo "Stopping sing-box@client..."
    sudo systemctl stop sing-box@client
end

function singbox-stat --description "show sing-box status"
    systemctl status sing-box@client --no-pager
end

# ----------------------- WHITELIST MANAGEMENT ------------------------

function singbox-wl-list --description "list whitelist domains"
    set wl_config "$SINGBOX_DIR/client-whitelist.json"
    if not test -f "$wl_config"
        echo "No $wl_config found"
        return 1
    end

    sudo sed -n '/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/{
        s/.*"domain_suffix":[[:space:]]*\["\([^"]*\)".*/\1/p
    }' "$wl_config"
end

function singbox-wl-add --description "add domain to whitelist"
    set domain "$argv[1]"
    if test -z "$domain"
        echo "Usage: singbox-wl-add example.com"
        return 1
    end

    set wl_config "$SINGBOX_DIR/client-whitelist.json"
    if not test -f "$wl_config"
        echo "Whitelist config $wl_config not found"
        return 1
    end

    if singbox-wl-list | grep -qx "$domain"
        echo "$domain already in whitelist"
        return 0
    end

    set tmp_file (mktemp)
    sudo awk -v dom="$domain" '
        /\/\/ WHITELIST-START/ {
            print
            print "      { \"outbound\": \"proxy\", \"domain_suffix\": [\"" dom "\"] },"
            next
        }
        { print }
    ' "$wl_config" > "$tmp_file"

    sudo mv "$tmp_file" "$wl_config"
    sudo chmod 644 "$wl_config"
    echo "Added $domain to whitelist"
end

function singbox-wl-del --description "remove domain from whitelist"
    set domain "$argv[1]"
    if test -z "$domain"
        echo "Usage: singbox-wl-del example.com"
        return 1
    end

    set wl_config "$SINGBOX_DIR/client-whitelist.json"
    if not test -f "$wl_config"
        echo "Whitelist config $wl_config not found"
        return 1
    end

    sudo sed -i "/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/ { /\"domain_suffix\":[[:space:]]*\[\"$domain\"/d }" "$wl_config"
    echo "Removed $domain from whitelist (if existed)"
end
