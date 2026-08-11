#!/bin/sh
if command -v systemctl >/dev/null 2>&1; then
    journalctl -u pac-server -n 50 --no-pager 2>/dev/null && exit 0
fi
echo "На Entware/OpenWrt pac-server не пишет отдельный лог-файл."
echo "Проверьте, что процесс жив: ps | grep pac-server"
