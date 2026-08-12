#!/bin/sh
# status.sh — 0 = запущен, 1 = остановлен, 2 = неизвестно.
init="/opt/etc/init.d/S99awg-manager"

if [ -x "$init" ]; then
    "$init" status >/dev/null 2>&1
    code=$?
    if [ "$code" -eq 0 ] || [ "$code" -eq 1 ]; then
        exit "$code"
    fi
fi

if command -v pidof >/dev/null 2>&1; then
    pidof awg-manager >/dev/null 2>&1 && exit 0 || exit 1
fi

exit 2
