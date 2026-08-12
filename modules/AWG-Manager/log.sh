#!/bin/sh
log_dir="/opt/var/log/awg-manager"

if [ -d "$log_dir" ]; then
    log_file=$(ls -t "$log_dir"/*.log 2>/dev/null | head -n1)
    if [ -n "$log_file" ] && [ -f "$log_file" ]; then
        tail -n 50 "$log_file"
    else
        echo "Лог-файлы не найдены в $log_dir"
    fi
else
    echo "Каталог логов не найден: $log_dir"
fi
