# sing-box server

Серверный baseline для Ubuntu: `sing-box + VLESS + Reality` с простым управлением клиентами.

## Что умеет

- ставит `sing-box`
- создаёт `systemd` сервис
- генерирует `Reality` ключи
- хранит клиентов в отдельном state-файле
- даёт команды:
  - `install`
  - `add`
  - `del`
  - `list`
  - `get`

## Файлы

- [install.sh](./install.sh) - установка сервера
- [add.sh](./add.sh) - добавить клиента
- [del.sh](./del.sh) - удалить клиента
- [list.sh](./list.sh) - список клиентов и трафик
- [get.sh](./get.sh) - получить `vless://` ссылку
- [common.sh](./common.sh) - общие функции

## Для кого

Если человек вообще не хочет руками собирать JSON, логика такая:

1. Один раз запустить установку.
2. Добавить клиента по имени.
3. Забрать его `vless://` ссылку.
4. Отдать ссылку клиенту.

## Быстрый старт на чистой Ubuntu

### Вариант с IP

```bash
cd sing-box/server
SERVER_HOST=1.2.3.4 ./install.sh
```

### Вариант с доменом

```bash
cd sing-box/server
SERVER_HOST=vpn.example.com ./install.sh
```

### Сразу создать первого клиента

```bash
SERVER_HOST=vpn.example.com INITIAL_CLIENT=me ./install.sh
```

## После установки

Появятся команды:

```bash
singbox-add phone
singbox-del phone
singbox-list
singbox-get phone
```

## Что делают команды

### Добавить клиента

```bash
./add.sh phone
```

Или после установки:

```bash
singbox-add phone
```

Скрипт:

- создаёт UUID
- добавляет клиента в state
- пересобирает `config.json`
- перезапускает `sing-box`
- печатает готовую `vless://` ссылку

### Удалить клиента

```bash
./del.sh phone
```

### Показать всех клиентов

```bash
./list.sh
```

### Показать ссылку одного клиента

```bash
./get.sh phone
```

## Что где лежит

- конфиг `sing-box`: `/etc/sing-box/config.json`
- state с клиентами: `/etc/sing-box/manager.json`
- helper-библиотека: `/usr/local/lib/singbox-manager/common.sh`
- команды после установки:
  - `/usr/local/sbin/singbox-install`
  - `/usr/local/sbin/singbox-add`
  - `/usr/local/sbin/singbox-del`
  - `/usr/local/sbin/singbox-list`
  - `/usr/local/sbin/singbox-get`

## Важные переменные установки

Можно переопределять через env:

```bash
\
  SERVER_HOST=vpn.example.com \
  SERVER_PORT=443 \
  REALITY_SERVER_NAME=www.cloudflare.com \
  REALITY_HANDSHAKE_SERVER=www.cloudflare.com \
  REALITY_HANDSHAKE_PORT=443 \
  ./install.sh
```

### Что значат

- `SERVER_HOST` - адрес, который попадёт в `vless://` ссылку
- `SERVER_PORT` - порт сервера
- `REALITY_SERVER_NAME` - SNI для клиента
- `REALITY_HANDSHAKE_SERVER` - куда маскируется Reality
- `REALITY_HANDSHAKE_PORT` - порт сайта маскировки
- `INITIAL_CLIENT` - первый клиент, если нужен сразу

## Трафик в `list`

`list.sh` просто показывает всех клиентов из state-файла.

Без per-user трафика и без зависимости от API-ответов конкретной сборки `sing-box`.

## Минимальный рабочий сценарий

```bash
cd sing-box/server
SERVER_HOST=vpn.example.com ./install.sh
./add.sh iphone
./get.sh iphone
```
