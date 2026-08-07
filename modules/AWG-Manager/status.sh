#!/bin/sh
pid_file="$KT_MODULE_DIR/data/service.pid"

if [ ! -f "$pid_file" ]; then
    exit 1
fi

pid=$(cat "$pid_file")
if kill -0 "$pid" 2>/dev/null; then
    exit 0
else
    exit 1
fi
