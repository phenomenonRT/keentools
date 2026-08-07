#!/bin/sh
# pid_file="$KT_MODULE_DIR/data/service.pid"

# if [ ! -f "$pid_file" ]; then
#     exit 0
# fi

# pid=$(cat "$pid_file")
# if kill -0 "$pid" 2>/dev/null; then
#     kill "$pid" 2>/dev/null
#     sleep 1
#     kill -9 "$pid" 2>/dev/null
# fi
# rm -f "$pid_file"
neo stop 
exit 0
