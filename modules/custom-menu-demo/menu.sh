#!/bin/sh
# menu.sh — Персональное меню проекта custom-menu-demo
# Этот файл находится внутри директории модуля и управляет его меню.

kt_read() {
    var="$1"
    if [ -n "$ZSH_VERSION" ]; then
        read -r "$var"
    else
        read -r "$var"
    fi
}

kt_pause() {
    printf "\nНажмите Enter для продолжения..."
    kt_read _
}

while true; do
    clear 2>/dev/null
    echo "=================================================="
    echo "  Кастомное меню: Собственное меню проекта (демо)"
    echo "=================================================="
    echo

    # Динамическая сборка пунктов меню в кастомном скрипте
    n=0
    set --

    add_item() {
        n=$((n+1))
        eval "item_${n}_label=\"\$1\""
        eval "item_${n}_script=\"\$2\""
    }

    [ -f "$KT_MODULE_DIR/start.sh" ]   && add_item "Запустить сервис" "start.sh"
    [ -f "$KT_MODULE_DIR/stop.sh" ]    && add_item "Остановить сервис" "stop.sh"
    [ -f "$KT_MODULE_DIR/restart.sh" ] && add_item "Перезапустить сервис" "restart.sh"
    [ -f "$KT_MODULE_DIR/logs/custom-menu-demo.log" ] && add_item "Просмотреть кастомный лог" "__log__"

    i=1
    while [ "$i" -le "$n" ]; do
        eval "lbl=\"\$item_${i}_label\""
        echo "$i. $lbl"
        i=$((i+1))
    done

    echo "0. Назад"
    echo
    printf "Выбор: "
    kt_read choice

    case "$choice" in
        0) exit 0 ;;
        [0-9]*)
            if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$n" ] 2>/dev/null; then
                eval "scr=\"\$item_${choice}_script\""
                case "$scr" in
                    __log__)
                        echo "--- Лог сервиса ---"
                        tail -n 20 "$KT_MODULE_DIR/logs/custom-menu-demo.log" 2>/dev/null || echo "Лог пуст"
                        kt_pause
                        ;;
                    *)
                        if [ -x "$KT_MODULE_DIR/$scr" ]; then
                            "$KT_MODULE_DIR/$scr"
                        elif [ -f "$KT_MODULE_DIR/$scr" ]; then
                            sh "$KT_MODULE_DIR/$scr"
                        fi
                        kt_pause
                        ;;
                esac
            else
                echo "Неверный выбор"
                kt_pause
            fi
            ;;
        *)
            echo "Неверный выбор"
            kt_pause
            ;;
    esac
done
