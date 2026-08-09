#!/bin/sh
logfile="$KT_MODULE_DIR/logs/standard-menu-demo.log"
if [ -f "$logfile" ]; then
    tail -n 20 "$logfile"
else
    echo "Лог-файл не найден."
fi
