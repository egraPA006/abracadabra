#!/usr/bin/env bash
set -euo pipefail

AWG_IF=awg0
AWG_DIR=/etc/amnezia/amneziawg
AWG_CONF="${AWG_DIR}/${AWG_IF}.conf"

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

[[ -f "$AWG_CONF" ]] || { echo "no $AWG_CONF" >&2; exit 1; }

if ! command -v awg >/dev/null 2>&1; then
  echo "awg binary not found in PATH" >&2
  exit 1
fi

if ! awg show "$AWG_IF" >/dev/null 2>&1; then
  echo "interface ${AWG_IF} is not up (awg show ${AWG_IF} failed)" >&2
  exit 1
fi

# Собираем map: pubkey -> "NAME IP"
declare -A NAME_BY_PUB

while read -r name pub ip; do
  NAME_BY_PUB["$pub"]="$name $ip"
done < <(
  awk '
  $1=="[Peer]" {
      inpeer=1
      name=""
      pub=""
      ip=""
      next
  }
  inpeer && /^# / {
      sub(/^# /,"")
      name=$0
      next
  }
  inpeer && $1=="PublicKey" {
      pub=$3
      next
  }
  inpeer && $1=="AllowedIPs" {
      ip=$3
      next
  }
  inpeer && NF==0 {
      if (pub != "") {
          if (name == "") name=pub
          print name, pub, ip
      }
      inpeer=0
      next
  }
  END {
      if (inpeer && pub != "") {
          if (name == "") name=pub
          print name, pub, ip
      }
  }
  ' "$AWG_CONF"
)

have_numfmt=0
if command -v numfmt >/dev/null 2>&1; then
  have_numfmt=1
fi

printf "%-20s %-18s %-12s %-12s %-20s\n" "NAME" "IP" "RX" "TX" "LAST_HANDSHAKE"
printf "%-20s %-18s %-12s %-12s %-20s\n" "--------------------" "------------------" "------------" "------------" "--------------------"

# awg show awg0 dump:
# line1: private listenPort fwmark
# peers: pub preshared endpoint allowedips latest_handshake rx tx persistent_keepalive
tail -n +2 < <(awg show "$AWG_IF" dump) | while read -r pub psk endpoint allowed latest rx tx keep; do
  [[ -z "${pub:-}" ]] && continue

  info="${NAME_BY_PUB[$pub]-$pub}"
  cname="$(printf '%s\n' "$info" | awk '{print $1}')"
  cip="$(printf '%s\n' "$info" | awk '{print $2}')"

  if [[ $have_numfmt -eq 1 ]]; then
    hr_rx=$(numfmt --to=iec --suffix=B "$rx" 2>/dev/null || echo "$rx")
    hr_tx=$(numfmt --to=iec --suffix=B "$tx" 2>/dev/null || echo "$tx")
  else
    hr_rx="$rx"
    hr_tx="$tx"
  fi

  if [[ "$latest" != "0" ]]; then
    hs=$(date -d "@$latest" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$latest")
  else
    hs="-"
  fi

  printf "%-20s %-18s %-12s %-12s %-20s\n" "$cname" "${cip:-"-"}" "$hr_rx" "$hr_tx" "$hs"
done
