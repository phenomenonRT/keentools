#!/bin/sh
mkdir -p "$KT_MODULE_DIR/data" "$KT_MODULE_DIR/logs"
echo "$$" > "$KT_MODULE_DIR/data/pid"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Стандартный демо-сервис запущен" >> "$KT_MODULE_DIR/logs/standard-menu-demo.log"
echo "Сервис запущен."
