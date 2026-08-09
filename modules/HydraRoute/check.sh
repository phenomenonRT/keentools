#!/bin/sh
# check.sh — реальная проверка установки: наличие пакета hrneo в opkg,
# а не файл-метка KeenTools. 0 = установлен, 1 = не установлен.
opkg list-installed 2>/dev/null | grep -q "^hrneo " && exit 0
exit 1
