#!/bin/sh
# check.sh — реальная проверка установки: наличие бинаря pac-server,
# а не файл-метка KeenTools. 0 = установлен, 1 = не установлен.
[ -x /opt/bin/pac-server ] && exit 0
[ -x /usr/local/bin/pac-server ] && exit 0
[ -x /usr/bin/pac-server ] && exit 0
exit 1
