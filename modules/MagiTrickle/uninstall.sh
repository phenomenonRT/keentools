#!/bin/sh
# uninstall.sh — стандартное удаление пакета magitrickle.
# Конфигурация (/opt/var/lib/magitrickle/) не удаляется автоматически —
# на случай, если пользователь захочет переустановить пакет позже.
if [ -x /opt/etc/init.d/S99magitrickle ]; then
    /opt/etc/init.d/S99magitrickle stop >/dev/null 2>&1 || true
fi
opkg remove magitrickle
echo "MagiTrickle удалён."
echo "Конфигурация сохранена (не удаляется автоматически): /opt/var/lib/magitrickle"
exit 0
