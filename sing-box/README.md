# sing-box

Набор bash-скриптов для Ubuntu:

- клиент `VLESS + Reality` для локальной машины
- сервер `VLESS + Reality` на `sing-box`
- простое управление без ручной правки JSON

## Что где

- [client](./client/README.md) - клиентские скрипты
- [server](./server/README.md) - серверные скрипты

## Для чего это

Если нужен простой baseline без панели и без сложной автоматики:

- на сервере один раз запускается `install.sh`
- дальше пользователи управляются командами `add`, `del`, `list`, `get`
- на клиенте из `vless://` генерируются готовые конфиги для `sing-box`

## Ubuntu

Скрипты писались под Ubuntu и ориентированы на:

- `apt`
- `systemd`
- запуск через `sudo`

## Быстрый сценарий

### Сервер

```bash
cd sing-box/server
SERVER_HOST=your.domain.or.ip ./install.sh
./add.sh phone
./get.sh phone
```

### Клиент

```bash
cd sing-box/client
sudo ./install.sh
./config.sh "vless://...."
source ./singbox.sh
singbox-on all
```

Подробности:

- [server/README.md](./server/README.md)
- [client/README.md](./client/README.md)
