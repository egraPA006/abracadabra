# Speedrun proxy

Маленький набор скриптов для поднятия AmneziaWG, Xray/Reality и sing-box/Reality.

## Структура

- `amnezia/`
  - `init.sh` — поднять AmneziaWG-сервер
  - `add-client.sh` / `del-client.sh` / `get-client.sh` / `list-clients.sh`
- `xray/`
  - `server/` — скрипты для Xray/Reality сервера
  - `client/` — скрипты для Xray клиента (SOCKS/HTTP на 10808)
- `sing-box/`
  - `server/` — серверные скрипты для sing-box/Reality
  - `client/` — клиентские скрипты для sing-box
- `readme.md` — это

## Порты и прокся

- `443/tcp` — Xray/Reality
- `443/tcp` — sing-box/Reality сервер
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

### 6. Если нужен именно sing-box

Сервер:

```bash
cd sing-box/server
SERVER_HOST=your.domain.or.ip ./install.sh
./add.sh phone
./get.sh phone
```

Клиент:

```bash
cd sing-box/client
sudo ./install.sh
./config.sh "vless://..."
source ./singbox.sh
singbox-on all
```

Подробные инструкции:

- [sing-box/README.md](/home/egrapa/prog/abracadabra/sing-box/README.md)
- [sing-box/server/README.md](/home/egrapa/prog/abracadabra/sing-box/server/README.md)
- [sing-box/client/README.md](/home/egrapa/prog/abracadabra/sing-box/client/README.md)
