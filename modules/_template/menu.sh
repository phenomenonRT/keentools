#!/bin/sh
# menu.sh — необязательный скрипт персонального меню модуля.
# Если этот файл находится в директории проекта ($KT_MODULE_DIR/menu.sh),
# при выборе данного модуля в KeenTools управление передаётся ему.
#
# Если файл menu.sh отсутствует — KeenTools использует стандартное меню
# и автоматически скрывает пункты для отсутствующих компонентов
# (например, если нет restart.sh, пункт "Перезапустить" не будет показан).

kt_read() {
    read -r "$1"
}

kt_pause() {
    printf "\nНажмите Enter..."
    kt_read _
}

while true; do
    clear 2>/dev/null
    echo "========================================"
    echo "  Своё меню проекта (шаблон)"
    echo "========================================"
    echo

    # Динамическая проверка компонентов перед выводом
    [ -f "$KT_MODULE_DIR/start.sh" ]   && echo "1. Запустить"
    [ -f "$KT_MODULE_DIR/stop.sh" ]    && echo "2. Остановить"
    [ -f "$KT_MODULE_DIR/restart.sh" ] && echo "3. Перезапустить"
    echo "0. Назад"
    echo
    printf "Выбор: "
    kt_read c

    case "$c" in
        1)
            [ -f "$KT_MODULE_DIR/start.sh" ] && "$KT_MODULE_DIR/start.sh"
            kt_pause
            ;;
        2)
            [ -f "$KT_MODULE_DIR/stop.sh" ] && "$KT_MODULE_DIR/stop.sh"
            kt_pause
            ;;
        3)
            [ -f "$KT_MODULE_DIR/restart.sh" ] && "$KT_MODULE_DIR/restart.sh"
            kt_pause
            ;;
        0)
            exit 0
            ;;
        *)
            echo "Неверный выбор"
            kt_pause
            ;;
    esac
done
