#!/bin/sh
if [ -x /opt/etc/init.d/S99pac-server ]; then
    /opt/etc/init.d/S99pac-server stop
elif [ -x /etc/init.d/pac-server ]; then
    /etc/init.d/pac-server stop
elif command -v systemctl >/dev/null 2>&1; then
    systemctl stop pac-server
else
    echo "Не найден init-скрипт/сервис pac-server"
    exit 1
fi
