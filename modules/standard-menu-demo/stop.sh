#!/bin/sh
if [ -f "$KT_MODULE_DIR/data/pid" ]; then
    rm -f "$KT_MODULE_DIR/data/pid"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Стандартный демо-сервис остановлен" >> "$KT_MODULE_DIR/logs/standard-menu-demo.log"
echo "Сервис остановлен."
