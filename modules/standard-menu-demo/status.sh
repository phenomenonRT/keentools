#!/bin/sh
if [ -f "$KT_MODULE_DIR/data/pid" ]; then
    exit 0
else
    exit 1
fi
