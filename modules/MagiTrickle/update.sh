#!/bin/sh
# update.sh — обновление пакета magitrickle через opkg (см. официальную
# инструкцию: https://magitrickle.dev/docs/getting-started/entware/).
opkg update
opkg install magitrickle

if [ -x /opt/etc/init.d/S99magitrickle ]; then
    /opt/etc/init.d/S99magitrickle restart
fi
exit 0
