#!/bin/sh
# uninstall.sh — стандартное удаление пакета hrneo.
# Для полной очистки (логи/конфиги/зависимости/hrweb/xray) используйте
# uninstall_all.sh — он вызывает официальный hr-uninstall.sh.
neo stop >/dev/null 2>&1 || true
opkg remove hrneo
exit 0
