#!/usr/bin/env bash
set -euo pipefail

CLIENTS_DIR="/root/amnezia/clients"

[[ $EUID -eq 0 ]] || { echo "run as root: sudo $0 <name>" >&2; exit 1; }

NAME=${1:-}
[[ -n "$NAME" ]] || { echo "usage: $0 client-name" >&2; exit 1; }

CONF="${CLIENTS_DIR}/${NAME}.conf"

[[ -f "$CONF" ]] || { echo "no config: ${CONF}" >&2; exit 1; }

if ! command -v qrencode >/dev/null 2>&1; then
  echo "qrencode not found, install it (apt install qrencode)" >&2
  exit 1
fi

echo "[*] showing QR for ${NAME} (${CONF})"
qrencode -t ansiutf8 < "$CONF"
echo
echo "[*] config path: ${CONF}"
