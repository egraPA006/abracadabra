# sing-box client

Клиентские скрипты для Ubuntu, которые принимают `vless://` ссылку и делают готовые конфиги `sing-box`.

## Файлы

- [install.sh](./install.sh) - ставит `sing-box`, создаёт `systemd` unit
- [config.sh](./config.sh) - из `vless://` делает конфиги
- [singbox.sh](./singbox.sh) - bash-команды управления
- [singbox.fish](./singbox.fish) - fish-команды управления

## Что получится

После генерации появятся конфиги:

- `/usr/local/etc/sing-box/client-all.json`
- `/usr/local/etc/sing-box/client-whitelist.json`
- `/usr/local/etc/sing-box/client-tun.json`

И сервис:

- `sing-box@client`

## Установка на Ubuntu

### 1. Поставить `sing-box` и unit-файл

```bash
cd sing-box/client
sudo ./install.sh
```

### 2. Сгенерировать конфиги из ссылки

```bash
./config.sh "vless://UUID@host:443?type=tcp&security=reality&fp=chrome&pbk=...&sid=...&sni=...&flow=xtls-rprx-vision#my-client"
```

### 3. Подключить команды в shell

Для bash:

```bash
source /path/to/repo/sing-box/client/singbox.sh
```

Для fish:

```fish
source /path/to/repo/sing-box/client/singbox.fish
```

Если хочешь постоянно, добавь `source .../singbox.sh` в `~/.bashrc`.

## Режимы запуска

### `singbox-on all`

Запускает режим без TUN. Трафик приложений, которые умеют ходить в локальный proxy `127.0.0.1:10808`, будет идти через сервер.

### `singbox-on wl`

Тоже без TUN, но через proxy пойдут только домены из whitelist.

### `singbox-on tun`

Полный VPN-режим через TUN. Весь системный трафик пойдёт через `sing-box`, кроме локальных сетей.

## Полезные команды

```bash
singbox-on all
singbox-on wl
singbox-on tun
singbox-off
singbox-stat
```

## Управление whitelist

Проверить список:

```bash
singbox-wl-list
```

Добавить домен:

```bash
singbox-wl-add openai.com
```

Удалить домен:

```bash
singbox-wl-del openai.com
```

## Где что лежит

- конфиги: `/usr/local/etc/sing-box/`
- активный конфиг сервиса: `/usr/local/etc/sing-box/client.json`
- unit: `/etc/systemd/system/sing-box@.service`

## Частый сценарий

```bash
cd sing-box/client
sudo ./install.sh
./config.sh "vless://...."
source ./singbox.sh
singbox-on all
singbox-stat
```
