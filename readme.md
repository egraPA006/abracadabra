````markdown
# Egor VPN stack (AmneziaWG + Xray/Reality)

Маленький набор скриптов для поднятия AmneziaWG и Xray/Reality.

## Структура

- `amnezia/`
  - `init.sh` — поднять AmneziaWG-сервер
  - `add-client.sh` / `del-client.sh` / `get-client.sh` / `list-clients.sh`
- `xray/`
  - `server/` — скрипты для Xray/Reality сервера
  - `client/` — скрипты для Xray клиента (SOCKS/HTTP на 10808)
- `readme.md` — это

## Порты и прокся

- `443/tcp` — Xray/Reality
- `51820/udp` — AmneziaWG (AWG)
- `10808/tcp` — локальный SOCKS/HTTP прокси клиента

Убедись, что 443/tcp и 51820/udp открыты снаружи.

## Быстрая установка

### 1. Забрать репозиторий

```bash
git clone <этот-репозиторий> egor-vpn
cd egor-vpn
````

### 2. Поставить AmneziaWG из исходников

```bash
git clone https://github.com/amnezia-vpn/amneziawg-go.git
cd amneziawg-go
make
sudo install -m 755 awg awg-quick /usr/local/bin/
cd ..
```

(главное, чтобы `awg` и `awg-quick` были в `$PATH`)

### 3. Поставить Xray-core (скачать готовый бинари)

```bash
cd /tmp
curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip
unzip xray.zip
sudo install -m 755 xray /usr/local/bin/xray
cd -
```

### 4. Инициализировать AmneziaWG

```bash
cd amnezia
sudo ./init.sh
```

### 5. Подготовить Xray (сервер и клиент)

```bash
cd xray/server
sudo ./create-config.sh
cd ../client
./create_config.sh
```

Дальше пользоваться скриптами по именам — очевидно. 😈

```
```
