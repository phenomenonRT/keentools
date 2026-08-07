#!/bin/sh
log_file="$KT_MODULE_DIR/data/example-service.log"
if [ -f "$log_file" ]; then
    tail -n 50 "$log_file"
else
    echo "Лог пока пуст — сервис ещё не запускался"
fi
