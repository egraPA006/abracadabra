#!/usr/bin/env bash
set -euo pipefail

AWG_IF=awg0
AWG_DIR=/etc/amnezia/amneziawg
AWG_CONF="${AWG_DIR}/${AWG_IF}.conf"

CLIENTS_DIR="/root/amnezia/clients"

[[ $EUID -eq 0 ]] || { echo "run as root: sudo $0 <name>" >&2; exit 1; }

NAME=${1:-}
[[ -n "$NAME" ]] || { echo "usage: $0 client-name" >&2; exit 1; }

[[ -f "$AWG_CONF" ]] || { echo "no $AWG_CONF" >&2; exit 1; }

grep -q "# ${NAME}\$" "$AWG_CONF" || { echo "client ${NAME} not found in ${AWG_CONF}" >&2; exit 1; }

TMP=$(mktemp)

awk -v name="$NAME" '
/^\[Peer]/ {
    inpeer=1
    buf=$0 ORS
    peername=""
    next
}
inpeer {
    buf = buf $0 ORS
    if ($0 ~ /^# /) {
        peername = substr($0,3)
    }
    if ($0 ~ /^$/) {
        if (peername != name) {
            printf "%s", buf
        }
        inpeer=0
        buf=""
        peername=""
    }
    next
}
{ print }
END {
    if (inpeer && peername != name) {
        printf "%s", buf
    }
}
' "$AWG_CONF" > "$TMP"

mv "$TMP" "$AWG_CONF"

# Чистим конфиг клиента, если есть
CONF="${CLIENTS_DIR}/${NAME}.conf"
if [[ -f "$CONF" ]]; then
    rm -f "$CONF"
    echo "[*] removed client config: $CONF"
else
    echo "[*] no client config file at $CONF (already removed?)"
fi

echo "[*] restarting ${AWG_IF}..."
if systemctl list-unit-files | grep -q '^awg-quick@\.service'; then
    systemctl restart awg-quick@"${AWG_IF}"
else
    awg-quick down "${AWG_IF}" 2>/dev/null || true
    awg-quick up "${AWG_IF}"
fi

echo "client ${NAME} removed and ${AWG_IF} restarted"
