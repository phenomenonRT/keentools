#!/bin/sh
# log.sh — лог демона HydraRoute Neo.
# По умолчанию логирование выключено (log=off в hrneo.conf) — путь к файлу
# читаем из конфига, если он там задан, иначе используем дефолт демона.
conf="/opt/etc/HydraRoute/hrneo.conf"
log_file="/opt/var/log/LOGhrneo.log"

if [ -f "$conf" ]; then
    cfg_path=$(grep -E '^logfile=' "$conf" 2>/dev/null | tail -n1 | cut -d'=' -f2-)
    [ -n "$cfg_path" ] && log_file="$cfg_path"
fi

if [ -f "$log_file" ]; then
    tail -n 50 "$log_file"
else
    echo "Лог не найден: $log_file"
    echo "Проверьте параметр 'log' в $conf (по умолчанию log=off)"
fi
