#!/bin/sh
if [ -f "$KT_MODULE_DIR/data/pid" ]; then
    rm -f "$KT_MODULE_DIR/data/pid"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Кастомный демо-сервис остановлен" >> "$KT_MODULE_DIR/logs/custom-menu-demo.log"
echo "Кастомный сервис остановлен."
