#!/bin/sh
init="/opt/etc/init.d/S99magitrickle"
if [ -x "$init" ]; then
    "$init" restart
else
    echo "Не найден init-скрипт $init"
    exit 1
fi
