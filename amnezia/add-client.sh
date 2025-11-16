#!/usr/bin/env bash
set -euo pipefail

AWG_IF=awg0
AWG_DIR=/etc/amnezia/amneziawg
AWG_CONF="${AWG_DIR}/${AWG_IF}.conf"
NET_PREFIX="10.10.0"   # 10.10.0.X
AWG_PORT=51820
DNS="1.1.1.1"

CLIENTS_DIR="/root/amnezia/clients"

[[ $EUID -eq 0 ]] || { echo "run as root: sudo $0 <name>" >&2; exit 1; }

NAME=${1:-}
[[ -n "$NAME" ]] || { echo "usage: $0 client-name" >&2; exit 1; }

[[ -f "$AWG_CONF" ]] || { echo "no $AWG_CONF (run init-server first)" >&2; exit 1; }

mkdir -p "$CLIENTS_DIR"

echo "[*] picking free IP in ${NET_PREFIX}.0/24..."
USED=$(grep -oE "${NET_PREFIX}\.[0-9]+/32" "$AWG_CONF" 2>/dev/null | sed -E "s#${NET_PREFIX}\.([0-9]+)/32#\1#" || true)

if [[ -n "$USED" ]]; then
  LAST=$(echo "$USED" | sort -n | tail -1)
  NEXT=$((LAST + 1))
else
  NEXT=2
fi
(( NEXT < 255 )) || { echo "no free IPs left" >&2; exit 1; }

IP="${NET_PREFIX}.${NEXT}"
CLIENT_TUN_IP="${IP}/32"
echo "[*] ${NAME} -> ${CLIENT_TUN_IP}"

umask 077
PRIV=$(awg genkey)
PUB=$(printf '%s' "$PRIV" | awg pubkey)
PSK=$(awg genpsk)

SERVER_PUB=$(<"${AWG_DIR}/server.pub")
[[ -n "$SERVER_PUB" ]] || { echo "cannot get server public key (${AWG_DIR}/server.pub)" >&2; exit 1; }

SERVER_IP=$(curl -s https://ifconfig.io || echo "SERVER_IP_HERE")

# Берём значения обфускации из Interface (Jc/Jmin/Jmax/S/H должны совпадать)
read Jc Jmin Jmax S1 S2 H1 H2 H3 H4 < <(
    awk '
    $1=="Jc"  {jc=$3}
    $1=="Jmin"{jmin=$3}
    $1=="Jmax"{jmax=$3}
    $1=="S1" {s1=$3}
    $1=="S2" {s2=$3}
    $1=="H1" {h1=$3}
    $1=="H2" {h2=$3}
    $1=="H3" {h3=$3}
    $1=="H4" {h4=$3}
    END{print jc, jmin, jmax, s1, s2, h1, h2, h3, h4}
    ' "$AWG_CONF"
)

if [[ -z "${Jc:-}" || -z "${Jmin:-}" || -z "${Jmax:-}" ]]; then
  echo "cannot read Jc/Jmin/Jmax from ${AWG_CONF}" >&2
  exit 1
fi

echo "[*] appending peer to ${AWG_CONF}..."
cat >> "$AWG_CONF" <<EOF

[Peer]
# ${NAME}
PresharedKey = ${PSK}
PublicKey = ${PUB}
AllowedIPs = ${CLIENT_TUN_IP}
EOF

echo "[*] restarting ${AWG_IF}..."
if systemctl list-unit-files | grep -q '^awg-quick@\.service'; then
    systemctl restart awg-quick@"${AWG_IF}"
else
    awg-quick down "${AWG_IF}" 2>/dev/null || true
    awg-quick up "${AWG_IF}"
fi

OUT="${CLIENTS_DIR}/${NAME}.conf"
echo "[*] writing client config to ${OUT}"

cat > "$OUT" <<EOF
[Interface]
# ${NAME}
PrivateKey = ${PRIV}
Address = ${CLIENT_TUN_IP}
DNS = ${DNS}
Jc = ${Jc}
Jmin = ${Jmin}
Jmax = ${Jmax}
S1 = ${S1}
S2 = ${S2}
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}

[Peer]
PresharedKey = ${PSK}
PublicKey = ${SERVER_PUB}
Endpoint = ${SERVER_IP}:${AWG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20
EOF

chmod 600 "$OUT"

qrencode -t ansiutf8 < "$OUT"
echo "=== done ==="
echo "client:     ${NAME}"
echo "ip:         ${CLIENT_TUN_IP}"
echo "config:     ${OUT}"
echo "client pub: ${PUB}"
