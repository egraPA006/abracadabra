#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  source "$SCRIPT_DIR/common.sh"
else
  source /usr/local/lib/singbox-manager/common.sh
fi

require_root
require_state
require_cmds jq numfmt

stats_json='[]'
stats_warning=""

if raw_stats="$(api_get "/users/stats" 2>/dev/null || true)"; then
  if [[ -n "$raw_stats" ]]; then
    stats_json="$(printf '%s' "$raw_stats" | normalize_stats)"
  fi
fi

if [[ "$stats_json" == "[]" ]]; then
  if raw_stats="$(api_get "/users" 2>/dev/null || true)"; then
    if [[ -n "$raw_stats" ]]; then
      stats_json="$(printf '%s' "$raw_stats" | normalize_stats)"
    fi
  fi
fi

if [[ "$stats_json" == "[]" ]]; then
  stats_warning="Clash API не вернул per-user статистику, показываю клиентов с нулевым трафиком."
fi

report_json="$(jq -n \
  --slurpfile state "$STATE_PATH" \
  --argjson stats "$stats_json" '
  ($state[0].clients // [])
  | map(
      . as $client
      | ([ $stats[] | select(.name == $client.name) ][0] // {}) as $stat
      | {
          name: $client.name,
          upload: ($stat.upload // 0),
          download: ($stat.download // 0),
          total: (($stat.upload // 0) + ($stat.download // 0))
        }
    )
  ' )"

if [[ "$(jq 'length' <<<"$report_json")" -eq 0 ]]; then
  echo "Клиентов нет"
  exit 0
fi

tmp_tsv="$(mktemp)"
jq -r '.[] | [.name, (.upload | tostring), (.download | tostring), (.total | tostring)] | @tsv' \
  <<<"$report_json" >"$tmp_tsv"

table_output="$({
  printf 'NAME\tUPLOAD\tDOWNLOAD\tTOTAL\n'
  cat "$tmp_tsv"
  jq -r '
    [
      "SUM",
      (map(.upload) | add | tostring),
      (map(.download) | add | tostring),
      (map(.total) | add | tostring)
    ] | @tsv
  ' <<<"$report_json"
} | numfmt --field=2-4 --to=iec --suffix=B --format="%.2f")"

if command -v column >/dev/null 2>&1; then
  printf '%s\n' "$table_output" | column -t -s $'\t'
else
  printf '%s\n' "$table_output"
fi

rm -f "$tmp_tsv"

if [[ -n "$stats_warning" ]]; then
  echo
  echo "$stats_warning"
fi
