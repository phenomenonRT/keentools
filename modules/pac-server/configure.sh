#!/bin/sh
# configure.sh — показывает путь и содержимое config.json.
# Сам JSON редактируется вручную (профили PAC, listen_ip/listen_port) —
# после правки нужно перезапустить сервис из меню, чтобы применить.
cfg="/opt/etc/pac-server/config.json"
[ -f "$cfg" ] || cfg="/etc/pac-server/config.json"

if [ ! -f "$cfg" ]; then
    echo "Файл конфигурации не найден (ожидался /opt/etc/pac-server/config.json или /etc/pac-server/config.json)"
    exit 1
fi

echo "Файл конфигурации: $cfg"
echo "----------------------------------------"
cat "$cfg"
echo "----------------------------------------"
echo
echo "Отредактируйте файл вручную, например:"
echo "  vi \"$cfg\""
echo "Затем выберите «Перезапустить» в меню pac-server, чтобы применить изменения."
echo
echo "Веб-интерфейс доступен по адресу http://<listen_ip>:<listen_port>/"
