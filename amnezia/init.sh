#!/usr/bin/env bash
set -euo pipefail

# === НАСТРОЙКИ ===
AWG_IF=awg0
AWG_DIR=/etc/amnezia/amneziawg
AWG_CONF="${AWG_DIR}/${AWG_IF}.conf"

AWG_PORT=51820
SERVER_TUN_IP=10.10.0.1/24
DNS=1.1.1.1   # просто инфа, в конфиг сервера не идёт

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

WAN_IF=$(ip route show default | awk '/default/ {print $5; exit}')
[[ -n "$WAN_IF" ]] || { echo "cannot detect WAN interface" >&2; exit 1; }

mkdir -p "$AWG_DIR"
cd "$AWG_DIR"
umask 077

echo "[*] generating server keys..."
awg genkey | tee server.key | awg pubkey > server.pub

SERVER_PRIV=$(<server.key)
SERVER_PUB=$(<server.pub)

# Параметры обфускации (одни и те же для сервера и всех клиентов)
# Рекомендованные диапазоны из доков: Jc 3–10, Jmin ~50, Jmax ~1000 
Jc=7
Jmin=50
Jmax=1000

# Сдвиги и заголовки — можно зарандомить, главное: одинаковые на сервере и клиентах
S1=$(shuf -i 40-200 -n1)
S2=$(shuf -i 40-200 -n1)
H1=$(shuf -i 1-2147483647 -n1)
H2=$(shuf -i 1-2147483647 -n1)
H3=$(shuf -i 1-2147483647 -n1)
H4=$(shuf -i 1-2147483647 -n1)

echo "[*] writing ${AWG_CONF}..."

cat > "$AWG_CONF" <<EOF
[Interface]
PrivateKey = ${SERVER_PRIV}
Address = ${SERVER_TUN_IP}
ListenPort = ${AWG_PORT}
Jc = ${Jc}
Jmin = ${Jmin}
Jmax = ${Jmax}
S1 = ${S1}
S2 = ${S2}
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}

PostUp   = iptables -A FORWARD -i ${AWG_IF} -j ACCEPT; iptables -A FORWARD -o ${AWG_IF} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${AWG_IF} -j ACCEPT; iptables -D FORWARD -o ${AWG_IF} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE
EOF

echo "[*] enabling ip_forward..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-amneziawg.conf
sysctl -q -p /etc/sysctl.d/99-amneziawg.conf

echo "[*] bringing up ${AWG_IF}..."
# Если у тебя есть systemd unit awg-quick@.service – можно использовать его.
if systemctl list-unit-files | grep -q '^awg-quick@\.service'; then
    systemctl enable awg-quick@"${AWG_IF}" --now
else
    awg-quick down "${AWG_IF}" 2>/dev/null || true
    awg-quick up "${AWG_IF}"
fi

echo "=== DONE ==="
echo "Server interface: ${AWG_IF}"
echo "Server pub:       ${SERVER_PUB}"
echo
echo "Jc/Jmin/Jmax/S/H (обязательно одинаковые у всех клиентов):"
echo "  Jc=${Jc}, Jmin=${Jmin}, Jmax=${Jmax}"
echo "  S1=${S1}, S2=${S2}"
echo "  H1=${H1}, H2=${H2}, H3=${H3}, H4=${H4}"
