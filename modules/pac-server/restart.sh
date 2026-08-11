#!/bin/sh
if [ -x /opt/etc/init.d/S99pac-server ]; then
    /opt/etc/init.d/S99pac-server restart
elif [ -x /etc/init.d/pac-server ]; then
    /etc/init.d/pac-server restart
elif command -v systemctl >/dev/null 2>&1; then
    systemctl restart pac-server
else
    echo "Не найден init-скрипт/сервис pac-server"
    exit 1
fi
