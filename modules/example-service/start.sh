#!/bin/sh
data_dir="$KT_MODULE_DIR/data"
pid_file="$data_dir/service.pid"
mkdir -p "$data_dir"

if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "Уже запущен (PID $(cat "$pid_file"))"
    exit 0
fi

nohup "$KT_MODULE_DIR/worker.sh" "$data_dir" >/dev/null 2>&1 &
echo $! > "$pid_file"
sleep 1

if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    exit 0
else
    exit 1
fi
