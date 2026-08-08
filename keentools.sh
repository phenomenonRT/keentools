#!/bin/sh
# keentools.sh — Keenetic Project Manager (KeenTools)
# Единая точка входа. Сам менеджер ничего не знает о конкретных проектах —
# все они подключаются как модули в modules/*/info.json.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

kt_src="$0"
while [ -h "$kt_src" ]; do
    kt_link=$(readlink "$kt_src")
    case "$kt_link" in
        /*) kt_src="$kt_link" ;;
        *)  kt_src="$(dirname "$kt_src")/$kt_link" ;;
    esac
done
SCRIPT_DIR=$(cd "$(dirname "$kt_src")" && pwd)
unset kt_src kt_link

KT_HOME="$SCRIPT_DIR"
export KT_HOME

. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/config.sh"
. "$SCRIPT_DIR/lib/modules.sh"
. "$SCRIPT_DIR/lib/deps.sh"
. "$SCRIPT_DIR/lib/backup.sh"
. "$SCRIPT_DIR/lib/diagnostics.sh"
. "$SCRIPT_DIR/lib/update.sh"

kt_init_dirs
kt_config_ensure

kt_nth() {
    n="$1"; shift
    i=1
    for a in "$@"; do
        if [ "$i" -eq "$n" ]; then echo "$a"; return 0; fi
        i=$((i+1))
    done
    return 1
}

# ---------------------------------------------------------------------------
# Каталог проектов — установка новых модулей
# ---------------------------------------------------------------------------
kt_menu_catalog() {
    while true; do
        clear 2>/dev/null
        kt_header "Каталог проектов"

        set --
        for name in $(kt_module_list_available); do
            set -- "$@" "$name"
        done

        if [ "$#" -eq 0 ]; then
            kt_ok "Все доступные проекты уже установлены"
            kt_pause
            return
        fi

        i=1
        for name in "$@"; do
            printf "%2d. %s %b(%s)%b\n" "$i" "$(kt_module_name "$name")" "$C_GRAY" "$(kt_module_description "$name")" "$C_RESET"
            i=$((i+1))
        done
        echo
        echo " 0. Назад"
        echo
        printf "Выберите проект для установки (можно несколько через пробел): "
        kt_read choice
        [ "$choice" = "0" ] && return

        for c in $choice; do
            sel=$(kt_nth "$c" "$@")
            if [ -z "$sel" ]; then
                kt_warn "Неверный номер: $c"
                continue
            fi
            echo
            if kt_confirm "Установить $(kt_module_name "$sel")?"; then
                kt_module_install "$sel"
            fi
        done
        kt_pause
    done
}

# ---------------------------------------------------------------------------
# Меню конкретного установленного модуля.
#
# Если у модуля есть свой menu.sh — управление полностью передаётся ему
# (он получает те же KT_HOME/KT_MODULE_DIR в окружении и может рисовать
# что угодно). Если menu.sh нет — используется стандартное меню, но
# пункты для отсутствующих скриптов (restart.sh/configure.sh/log.sh/...)
# просто не показываются, вместо "заглушки с предупреждением".
# ---------------------------------------------------------------------------
kt_menu_module() {
    name="$1"

    if kt_module_has_script "$name" menu.sh; then
        kt_module_run "$name" menu.sh
        return
    fi

    while true; do
        clear 2>/dev/null
        kt_header "$(kt_module_name "$name")"
        echo "Статус:  $(kt_module_status_text "$name")"
        echo "Версия:  $(kt_module_installed_version "$name")"
        echo

        # Пункты меню собираются динамически: показываем только то, что
        # у модуля реально есть (start.sh считается обязательным всегда).
        n=0
        set --
        add_item() {
            n=$((n+1))
            eval "kt_item_${n}_label=\"\$1\""
            eval "kt_item_${n}_script=\"\$2\""
        }

        add_item "Запустить"        "start.sh"
        add_item "Остановить"       "stop.sh"
        kt_module_has_script "$name" restart.sh   && add_item "Перезапустить"     "restart.sh"
        kt_module_has_script "$name" update.sh    && add_item "Обновить"          "update.sh"
        kt_module_has_script "$name" configure.sh && add_item "Настроить"         "configure.sh"
        if kt_module_has_script "$name" log.sh || [ -f "$(kt_module_dir "$name")/logs/${name}.log" ]; then
            add_item "Посмотреть лог" "__log__"
        fi
        add_item "Удалить" "__uninstall__"

        i=1
        while [ "$i" -le "$n" ]; do
            eval "lbl=\"\$kt_item_${i}_label\""
            echo "$i. $lbl"
            i=$((i+1))
        done
        echo
        echo "0. Назад"
        echo
        printf "Выбор: "
        kt_read c

        case "$c" in
            0) return ;;
            [0-9]*)
                if [ "$c" -ge 1 ] 2>/dev/null && [ "$c" -le "$n" ] 2>/dev/null; then
                    eval "scr=\"\$kt_item_${c}_script\""
                    case "$scr" in
                        start.sh)   kt_module_start "$name"; kt_pause ;;
                        stop.sh)    kt_module_stop "$name"; kt_pause ;;
                        restart.sh) kt_module_restart "$name"; kt_pause ;;
                        update.sh)  kt_module_update "$name"; kt_pause ;;
                        configure.sh) kt_module_run "$name" configure.sh; kt_pause ;;
                        __log__)    kt_menu_module_log "$name" ;;
                        __uninstall__)
                            if kt_confirm "Точно удалить $(kt_module_name "$name")?"; then
                                kt_module_uninstall "$name"
                                kt_pause
                                return
                            fi
                            ;;
                    esac
                else
                    kt_warn "Неверный выбор"
                fi
                ;;
            *) kt_warn "Неверный выбор" ;;
        esac
    done
}

kt_menu_module_log() {
    name="$1"
    mdir=$(kt_module_dir "$name")
    clear 2>/dev/null
    kt_header "Лог: $(kt_module_name "$name")"
    if [ -f "$mdir/log.sh" ]; then
        kt_module_run "$name" log.sh
    elif [ -f "$mdir/logs/${name}.log" ]; then
        tail -n 50 "$mdir/logs/${name}.log"
    else
        kt_warn "Лог для этого модуля не найден"
    fi
    kt_pause
}

# ---------------------------------------------------------------------------
# Настройки менеджера
# ---------------------------------------------------------------------------
kt_menu_settings() {
    while true; do
        clear 2>/dev/null
        kt_header "Настройки"
        paused_note=""
        kt_updates_are_paused && paused_note=" ${C_YELLOW}(на паузе)${C_RESET}"
        echo " 1. Проверять обновления при запуске:   $(kt_config_get KT_CHECK_ON_START)$paused_note"
        echo " 2. Периодичность проверки:              $(kt_config_get KT_CHECK_FREQUENCY)"
        echo " 3. Проверять обновления проектов:        $(kt_config_get KT_CHECK_MODULE_UPDATES)"
        echo " 4. Проверять обновления менеджера:        $(kt_config_get KT_CHECK_SELF_UPDATES)"
        echo " 5. URL репозитория для самообновления:    $(kt_config_get KT_REPO_URL)"
        echo " 6. Отключить цветной вывод:               $(kt_config_get KT_NO_COLOR)"
        echo " 7. Тихая/быстрая проверка обновлений:     $(kt_config_get KT_CHECK_QUIET)"
        echo " 8. Источник установки:                    $(kt_config_get KT_INSTALL_SOURCE)"
        echo " 9. Зеркала GitHub (через запятую):        $(kt_config_get KT_GITHUB_MIRRORS)"
        echo "10. Приостановить проверку обновлений"
        echo
        echo " 0. Назад"
        echo
        printf "Выбор: "
        kt_read c
        case "$c" in
            1)
                cur=$(kt_config_get KT_CHECK_ON_START)
                [ "$cur" = "yes" ] && kt_config_set KT_CHECK_ON_START no || kt_config_set KT_CHECK_ON_START yes
                ;;
            2)
                echo "1) always  2) daily  3) weekly  4) never"
                printf "Выбор: "; kt_read f
                case "$f" in
                    1) kt_config_set KT_CHECK_FREQUENCY always ;;
                    2) kt_config_set KT_CHECK_FREQUENCY daily ;;
                    3) kt_config_set KT_CHECK_FREQUENCY weekly ;;
                    4) kt_config_set KT_CHECK_FREQUENCY never ;;
                esac
                ;;
            3)
                cur=$(kt_config_get KT_CHECK_MODULE_UPDATES)
                [ "$cur" = "yes" ] && kt_config_set KT_CHECK_MODULE_UPDATES no || kt_config_set KT_CHECK_MODULE_UPDATES yes
                ;;
            4)
                cur=$(kt_config_get KT_CHECK_SELF_UPDATES)
                [ "$cur" = "yes" ] && kt_config_set KT_CHECK_SELF_UPDATES no || kt_config_set KT_CHECK_SELF_UPDATES yes
                ;;
            5)
                printf "Новый URL (пусто чтобы очистить): "
                kt_read url
                kt_config_set KT_REPO_URL "$url"
                ;;
            6)
                cur=$(kt_config_get KT_NO_COLOR)
                [ "$cur" = "1" ] && kt_config_set KT_NO_COLOR 0 || kt_config_set KT_NO_COLOR 1
                kt_warn "Изменение вступит в силу при следующем запуске"
                ;;
            7)
                cur=$(kt_config_get KT_CHECK_QUIET)
                [ "$cur" = "yes" ] && kt_config_set KT_CHECK_QUIET no || kt_config_set KT_CHECK_QUIET yes
                ;;
            8)
                echo "1) github  2) mirror"
                printf "Выбор: "; kt_read s
                case "$s" in
                    1) kt_config_set KT_INSTALL_SOURCE github ;;
                    2) kt_config_set KT_INSTALL_SOURCE mirror ;;
                esac
                ;;
            9)
                printf "Зеркала через запятую (пусто чтобы очистить): "
                kt_read mirrors
                kt_config_set KT_GITHUB_MIRRORS "$mirrors"
                ;;
            10)
                printf "На сколько дней приостановить проверку обновлений (0 = снять паузу): "
                kt_read d
                case "$d" in
                    ''|*[!0-9]*) kt_warn "Введите число" ;;
                    *) kt_pause_updates "$d" ;;
                esac
                kt_pause
                ;;
            0) return ;;
            *) kt_warn "Неверный выбор" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Логи менеджера
# ---------------------------------------------------------------------------
kt_menu_logs() {
    clear 2>/dev/null
    kt_header "Журнал KeenTools"
    if [ -f "$KT_LOG_FILE" ]; then
        tail -n 50 "$KT_LOG_FILE"
    else
        kt_info "Журнал пока пуст"
    fi
    kt_pause
}

# ---------------------------------------------------------------------------
# О программе
# ---------------------------------------------------------------------------
kt_menu_about() {
    clear 2>/dev/null
    kt_header "Keenetic Project Manager"
    echo "Версия:          $(kt_self_current_version)"
    echo "Каталог модулей: $KT_MODULES_DIR"
    echo
    echo "1. Проверить обновления"
    echo "2. Обновить"
    echo "3. Диагностика"
    echo "4. Резервное копирование"
    echo
    echo "0. Назад"
    echo
    printf "Выбор: "
    kt_read c
    case "$c" in
        1) kt_check_all_updates; kt_pause ;;
        2)
            new_ver=$(kt_self_check_update)
            if [ -n "$new_ver" ]; then
                kt_self_update "$new_ver"
            else
                kt_ok "У вас установлена последняя версия"
            fi
            kt_pause
            ;;
        3) kt_diagnostics_run; kt_pause ;;
        4) kt_menu_backup ;;
        0) return ;;
    esac
}

kt_menu_backup() {
    clear 2>/dev/null
    kt_header "Резервное копирование"
    echo "1. Создать резервную копию"
    echo "2. Восстановить"
    echo "0. Назад"
    echo
    printf "Выбор: "
    kt_read c
    case "$c" in
        1) kt_backup_create; kt_pause ;;
        2)
            set --
            for f in $(kt_backup_list); do set -- "$@" "$f"; done
            if [ "$#" -eq 0 ]; then
                kt_warn "Резервных копий не найдено"
                kt_pause
                return
            fi
            i=1
            for f in "$@"; do echo "$i) $(basename "$f")"; i=$((i+1)); done
            printf "Какую восстановить (0 - отмена): "
            kt_read n
            [ "$n" = "0" ] && return
            sel=$(kt_nth "$n" "$@")
            [ -n "$sel" ] && kt_backup_restore "$sel"
            kt_pause
            ;;
        0) return ;;
    esac
}

# ---------------------------------------------------------------------------
# Первый запуск: ничего не установлено
# ---------------------------------------------------------------------------
kt_first_run() {
    clear 2>/dev/null
    kt_header "Keenetic Project Manager"
    echo
    echo "Не найдено установленных проектов."
    echo
    kt_menu_catalog
}

# ---------------------------------------------------------------------------
# Главное меню
# ---------------------------------------------------------------------------
kt_menu_main() {
    # Автопроверка обновлений при запуске (согласно настройкам/частоте/паузе).
    # В "тихом" режиме (по умолчанию) это быстро: модули проверяются
    # параллельно, печатается только сводка при наличии обновлений.
    if kt_should_autocheck; then
        if kt_check_all_updates; then
            kt_pause
        fi
        kt_mark_checked_now
    fi

    while true; do
        clear 2>/dev/null
        kt_header "Keenetic Project Manager"

        set --
        for name in $(kt_module_list_installed); do
            set -- "$@" "$name"
        done

        if [ "$#" -eq 0 ]; then
            kt_first_run
            continue
        fi

        echo "Установлено:"
        echo
        i=1
        for name in "$@"; do
            printf "[%d] %-20s %b %s\n" "$i" "$(kt_module_name "$name")" "$(kt_module_status_dot "$name")" "$(kt_module_status_text "$name")"
            i=$((i+1))
        done
        echo
        echo "[I] Установить проект"
        echo "[U] Проверить обновления"
        echo "[S] Настройки"
        echo "[L] Логи"
        echo "[A] О программе"
        echo "[Q] Выход"
        echo
        printf "Выбор: "
        kt_read c

        case "$c" in
            [0-9]*)
                sel=$(kt_nth "$c" "$@")
                [ -n "$sel" ] && kt_menu_module "$sel" || kt_warn "Неверный номер"
                ;;
            [IiИи]) kt_menu_catalog ;;
            [UuУу]) kt_check_all_updates; kt_pause ;;
            [SsСс]) kt_menu_settings ;;
            [LlЛл]) kt_menu_logs ;;
            [AaАа]) kt_menu_about ;;
            [QqЙй]) echo "До встречи!"; exit 0 ;;
            *) kt_warn "Неверный выбор" ;;
        esac
    done
}

kt_menu_main
