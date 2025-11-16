# =====================================================================
# XRAY + REALITY CONTROL (FISH) — БЕЗ NFT/IPTABLES
# =====================================================================
set -g XRAY_DIR "/etc/xray"

function xray-on --description "start xray with mode: all or wl (no firewall magic)"
    set mode $argv[1]
    if test -z "$mode"
        set mode "all"
    end

    switch "$mode"
        case all
            set cfg "$XRAY_DIR/client-all.json"
        case wl whitelist
            set cfg "$XRAY_DIR/client-whitelist.json"
        case '*'
            echo "Usage: xray-on [all|wl]"
            echo "Available modes: all, wl (whitelist)"
            return 1
    end

    if not test -f "$cfg"
        echo "Config $cfg not found"
        return 1
    end

    echo "Using config $cfg"
    sudo ln -sf "$cfg" "$XRAY_DIR/client.json"

    echo "Restarting xray@client..."
    sudo systemctl restart xray@client
end

function xray-off --description "stop xray"
    echo "Stopping xray@client..."
    sudo systemctl stop xray@client
end

function xray-stat --description "show xray status"
    systemctl status xray@client --no-pager
end

# ----------------------- WHITELIST MANAGEMENT ------------------------

function xray-wl-list --description "list whitelist domains"
    set wl_config "$XRAY_DIR/client-whitelist.json"
    
    if not test -f "$wl_config"
        echo "No $wl_config found"
        return 1
    end

    sudo sed -n '/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/{
        s/.*\"domain:\([^\"]*\)\".*/\1/p
    }' "$wl_config"
end

function xray-wl-add --description "add domain to whitelist"
    set domain "$argv[1]"
    if test -z "$domain"
        echo "Usage: xray-wl-add example.com"
        return 1
    end

    set wl_config "$XRAY_DIR/client-whitelist.json"
    
    if not test -f "$wl_config"
        echo "Whitelist config $wl_config not found"
        return 1
    end

    if xray-wl-list | grep -qx "$domain"
        echo "$domain already in whitelist"
        return 0
    end

    set tmp_file (mktemp)

    sudo awk -v dom="$domain" '
        /\/\/ WHITELIST-START/ {
            print
            print "      {\"type\":\"field\",\"domain\":[\"domain:" dom "\"],\"outboundTag\":\"proxy\"},"
            next
        }
        { print }
    ' "$wl_config" > "$tmp_file"

    sudo mv "$tmp_file" "$wl_config"
    sudo chmod 644 "$wl_config"
    echo "Added $domain to whitelist"
end

function xray-wl-del --description "remove domain from whitelist"
    set domain "$argv[1]"
    if test -z "$domain"
        echo "Usage: xray-wl-del example.com"
        return 1
    end

    set wl_config "$XRAY_DIR/client-whitelist.json"
    
    if not test -f "$wl_config"
        echo "Whitelist config $wl_config not found"
        return 1
    end

    sudo sed -i "/\/\/ WHITELIST-START/,/\/\/ WHITELIST-END/ { /\"domain:$domain\"/d }" "$wl_config"
    echo "Removed $domain from whitelist (if existed)"
end