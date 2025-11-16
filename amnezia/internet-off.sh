#!/usr/bin/env bash
set -euo pipefail

AWG_IF=awg0

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

WAN_IF=${WAN_IF:-$(ip route show default | awk '/default/ {print $5; exit 1}')}
[[ -n "$WAN_IF" ]] || { echo "cannot detect WAN interface" >&2; exit 1; }

echo "[*] disabling internet for ${AWG_IF} clients..."
echo "[*] WAN interface: ${WAN_IF}"

# Клиент → Интернет
iptables -D FORWARD -i "${AWG_IF}" -o "${WAN_IF}" -j ACCEPT 2>/dev/null || true

# Ответы
iptables -D FORWARD -i "${WAN_IF}" -o "${AWG_IF}" \
  -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# NAT
iptables -t nat -D POSTROUTING -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || true

echo "[*] done."
