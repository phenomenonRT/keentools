#!/bin/sh
# uninstall.sh — полное удаление awg-manager (пакет, репозиторий, данные, логи).
"$KT_MODULE_DIR/stop.sh" >/dev/null 2>&1 || true
opkg remove awg-manager
rm -f /opt/etc/opkg/awg_manager.conf
rm -rf /opt/etc/awg-manager /opt/var/lib/awg-manager /opt/var/log/awg-manager
opkg update >/dev/null 2>&1 || true
echo "AWG Manager удалён"
exit 0
