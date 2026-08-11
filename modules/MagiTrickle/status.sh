#!/bin/sh
# status.sh — 0 = запущен, 1 = остановлен, 2 = неизвестно.
# Сначала пробуем стандартный init.d-скрипт Entware, если он умеет
# отвечать на "status" кодом возврата 0/1; иначе проверяем сам процесс.
init="/opt/etc/init.d/S99magitrickle"

if [ -x "$init" ]; then
    "$init" status >/dev/null 2>&1
    code=$?
    if [ "$code" -eq 0 ] || [ "$code" -eq 1 ]; then
        exit "$code"
    fi
fi

if command -v pidof >/dev/null 2>&1; then
    pidof magitrickle >/dev/null 2>&1 && exit 0 || exit 1
fi

exit 2
