#!/bin/sh
# install.sh — установка MagiTrickle по официальной инструкции для Entware
# (https://magitrickle.dev/docs/getting-started/entware/):
# добавление репозитория пакетов -> opkg install -> первый запуск.
set -e

wget -qO- http://bin.magitrickle.dev/packages/add_repo.sh | sh
opkg update
opkg install magitrickle

if [ -x /opt/etc/init.d/S99magitrickle ]; then
    /opt/etc/init.d/S99magitrickle start
fi

echo "MagiTrickle установлен. Веб-интерфейс: http://<IP роутера>:8080"
exit 0
