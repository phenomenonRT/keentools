#!/bin/sh
# status.sh — 0 = запущен, 1 = остановлен, 2 = неизвестно.
if [ -x /opt/etc/init.d/S99pac-server ]; then
    /opt/etc/init.d/S99pac-server check >/dev/null 2>&1
    [ "$?" -eq 0 ] && exit 0 || exit 1
elif [ -x /etc/init.d/pac-server ]; then
    /etc/init.d/pac-server status >/dev/null 2>&1
    [ "$?" -eq 0 ] && exit 0 || exit 1
elif command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet pac-server && exit 0 || exit 1
else
    exit 2
fi
