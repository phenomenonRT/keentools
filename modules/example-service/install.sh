#!/bin/sh
set -e
data_dir="$KT_MODULE_DIR/data"
mkdir -p "$data_dir"
chmod +x "$KT_MODULE_DIR/worker.sh"
echo "Демо-сервис установлен. Данные: $data_dir"
exit 0
