#!/usr/bin/env bash
set -euo pipefail

# ================== НАСТРОЙКИ ==================
SINGBOX_BIN="${SINGBOX_BIN:-/usr/local/bin/sing-box}"
SINGBOX_DIR="${SINGBOX_DIR:-/usr/local/etc/sing-box}"
UNIT_PATH="${UNIT_PATH:-/etc/systemd/system/sing-box@.service}"

# ================== ПРОВЕРКА ROOT ==================
if [[ $EUID -ne 0 ]]; then
  echo "Этот скрипт лучше запускать от root, например:"
  echo "  sudo $0"
  exit 1
fi

# ================== УСТАНОВКА SING-BOX ==================
if ! command -v sing-box >/dev/null 2>&1 && [[ ! -x "$SINGBOX_BIN" ]]; then
  echo "[+] sing-box не найден, устанавливаю..."
  # Официальный инсталлер. Если хочешь — поменяй на пакетный менеджер.
  curl -fsSL https://sing-box.app/install.sh | sh
else
  echo "[=] sing-box уже установлен."
fi

# ================== ДИРЕКТОРИЯ КОНФИГОВ ==================
echo "[+] Создаю директорию конфигов: $SINGBOX_DIR"
mkdir -p "$SINGBOX_DIR"
chmod 755 "$SINGBOX_DIR"

# ================== SYSTEMD UNIT ==================
echo "[+] Пишу systemd unit: $UNIT_PATH"

cat > "$UNIT_PATH" <<'EOF'
[Unit]
Description=Sing-box instance %i
After=network-online.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
# ВАЖНО: конфиг ожидается по пути /usr/local/etc/sing-box/%i.json
# В наших fish-функциях используется instance "client" => client.json
ExecStart=/usr/bin/sing-box run -c /usr/local/etc/sing-box/%i.json
Restart=on-failure
RestartSec=3
WorkingDirectory=/usr/local/etc/sing-box

[Install]
WantedBy=multi-user.target
EOF

chmod 644 "$UNIT_PATH"

echo "[+] Перечитываю systemd units..."
systemctl daemon-reload

echo
echo "Готово."
echo
echo "Дальше шаги такие:"
echo "  1) Сгенерировать конфиги из vless:// (наш vless-to-singbox.sh):"
echo "       vless-to-singbox.sh \"vless://...\""
echo "  2) В fish дергать:"
echo "       singbox-on all   # или wl / tun"
echo "  3) Если всё ок — включить автозапуск:"
echo "       systemctl enable sing-box@client"
echo
echo "Сейчас сервис не стартую специально, пока нет client.json."
