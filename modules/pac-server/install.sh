#!/bin/sh
# install.sh — установка pac-server через официальный установщик проекта.
# Установщик сам определяет архитектуру, скачивает бинарь с GitHub Releases
# и на Entware ставит его в /opt/bin + создаёт init-скрипт
# /opt/etc/init.d/S99pac-server (а также, если найден uci, открывает
# нужный TCP-порт только для lo и br0 — WAN не трогает).
set -e

curl -fsSL "https://raw.githubusercontent.com/phenomenonRT/pac-server/main/install.sh" | sh

echo "pac-server установлен."
exit 0
