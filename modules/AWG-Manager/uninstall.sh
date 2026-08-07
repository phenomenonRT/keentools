#!/bin/sh
"$KT_MODULE_DIR/stop.sh" >/dev/null 2>&1 || true
rm -rf "$KT_MODULE_DIR/data"
echo "Демо-сервис удалён"
exit 0
