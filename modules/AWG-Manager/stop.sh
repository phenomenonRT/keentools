#!/bin/sh
init="/opt/etc/init.d/S99awg-manager"
if [ -x "$init" ]; then
    "$init" stop
else
    echo "Не найден init-скрипт $init"
    exit 1
fi
