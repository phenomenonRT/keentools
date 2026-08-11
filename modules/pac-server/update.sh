#!/bin/sh
# update.sh — повторный запуск официального установщика: он сам скачивает
# актуальный релиз под архитектуру устройства и перезапускает сервис.
set -e
curl -fsSL "https://raw.githubusercontent.com/phenomenonRT/pac-server/main/install.sh" | sh
exit 0
