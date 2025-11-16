#!/usr/bin/env bash
set -euo pipefail

# Адрес API Xray (у тебя dokodemo/tunnel на 127.0.0.1:62789 с tag "api")
APISERVER="127.0.0.1:62789"

# Путь к бинарнику Xray
XRAY_BIN="${XRAY_BIN:-/usr/local/bin/xray}"

if ! command -v "$XRAY_BIN" >/dev/null 2>&1; then
  echo "Не найден xray (ожидаю $XRAY_BIN, можно задать XRAY_BIN=/path/to/xray)."
  exit 1
fi

if ! command -v numfmt >/dev/null 2>&1; then
  echo "Не найден numfmt (coreutils). На Arch он есть по умолчанию."
  exit 1
fi

# Забираем статистику через xray api statsquery
apidata() {
  local reset_flag=""
  if [[ "${1:-}" == "reset" ]]; then
    reset_flag="-reset=true"
  fi

  "$XRAY_BIN" api statsquery --server="$APISERVER" $reset_flag \
    | awk '
      {
        # Ловим строку с "name": "user>>>email>>>traffic>>>uplink"
        if (match($1, /"name":/)) {
          f = 1
          # второй токен — это строка с именем ("user>>>...>>>uplink",)
          key = $2
          gsub(/[",]/, "", key)
          split(key, p, ">>>")
          # p[1] = user/inbound/outbound, p[2] = email/tag, p[4] = uplink/downlink
          printf "%s:%s->%s\t", p[1], p[2], p[4]
        } else if (match($1, /"value":/) && f) {
          # значение счётчика (в байтах)
          f = 0
          val = $2
          gsub(/[" ,]/, "", val)
          if (val == "") val = 0
          printf "%.0f\n", val
        } else if (match($0, /}/) && f) {
          # если по какой-то причине value не пришёл
          f = 0
          print 0
        }
      }
    '
}

print_sum() {
  local DATA="$1"
  local PREFIX="$2"

  # фильтруем по типу (inbound / outbound / user)
  local SORTED
  SORTED=$(echo "$DATA" | grep "^${PREFIX}:" | sort -r || true)

  if [[ -z "$SORTED" ]]; then
    echo "нет данных"
    return
  fi

  # считаем суммы по uplink/downlink
  local SUM
  SUM=$(echo "$SORTED" | awk '
    /->uplink/ { us+=$2 }
    /->downlink/ { ds+=$2 }
    END {
      if (us == "") us = 0;
      if (ds == "") ds = 0;
      printf "SUM->uplink:\t%.0f\nSUM->downlink:\t%.0f\nSUM->TOTAL:\t%.0f\n", us, ds, us+ds;
    }')

  # bytes -> KiB/MiB/GiB и выравнивание колонок
  echo -e "${SORTED}\n${SUM}" \
    | numfmt --field=2 --suffix=B --to=iec \
    | column -t
}

MODE="${1:-}"

DATA="$(apidata "$MODE")"

echo "=========== Inbounds ==========="
print_sum "$DATA" "inbound"
echo

echo "=========== Outbounds =========="
print_sum "$DATA" "outbound"
echo

echo "============ Users ============="
print_sum "$DATA" "user"
echo "================================"

if [[ "$MODE" == "reset" ]]; then
  echo "(Счётчики обнулены после этого вывода)"
fi
