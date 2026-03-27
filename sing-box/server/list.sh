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
require_cmds jq

report_json="$(jq '
  (.clients // [])
  | map({
      name: .name,
      uuid: .uuid,
      created_at: (.created_at // "")
    })
' "$STATE_PATH")"

if [[ "$(jq 'length' <<<"$report_json")" -eq 0 ]]; then
  echo "Клиентов нет"
  exit 0
fi

tmp_list="$(mktemp)"
jq -r '.[] | [.name, .uuid, .created_at] | @tsv' <<<"$report_json" | {
  printf 'NAME\tUUID\tCREATED\n'
  cat
} > "$tmp_list"

table_output="$(cat "$tmp_list")"
if command -v column >/dev/null 2>&1; then
  printf '%s\n' "$table_output" | column -t -s $'\t'
else
  printf '%s\n' "$table_output"
fi

rm -f "$tmp_list"
