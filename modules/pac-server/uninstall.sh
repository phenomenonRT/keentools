#!/bin/sh
# uninstall.sh — удаление pac-server.
#
# Официальный uninstall.sh репозитория умеет чистить только systemd-юнит
# и бинарь в /usr/local/bin — про Entware/OpenWrt (init.d-скрипт,
# /opt/bin) он не знает. Поэтому сначала аккуратно останавливаем и
# убираем init-скрипт/бинарь сами, а затем на всякий случай прогоняем
# и официальный скрипт (для systemd-систем).

if [ -f /opt/etc/init.d/S99pac-server ]; then
    /opt/etc/init.d/S99pac-server stop >/dev/null 2>&1 || true
    rm -f /opt/etc/init.d/S99pac-server
fi

if [ -f /etc/init.d/pac-server ]; then
    /etc/init.d/pac-server stop >/dev/null 2>&1 || true
    /etc/init.d/pac-server disable >/dev/null 2>&1 || true
    rm -f /etc/init.d/pac-server
fi

rm -f /opt/bin/pac-server /usr/local/bin/pac-server /usr/bin/pac-server

curl -fsSL "https://raw.githubusercontent.com/phenomenonRT/pac-server/main/uninstall.sh" 2>/dev/null | sh >/dev/null 2>&1 || true

echo "pac-server удалён."
echo "Конфигурация сохранена (не удаляется автоматически): /opt/etc/pac-server или /etc/pac-server"
exit 0
