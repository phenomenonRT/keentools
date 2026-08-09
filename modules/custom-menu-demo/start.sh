#!/bin/sh
mkdir -p "$KT_MODULE_DIR/data" "$KT_MODULE_DIR/logs"
echo "$$" > "$KT_MODULE_DIR/data/pid"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Кастомный демо-сервис запущен" >> "$KT_MODULE_DIR/logs/custom-menu-demo.log"
echo "Кастомный сервис запущен."
