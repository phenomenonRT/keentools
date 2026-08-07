#!/bin/sh
# modules.sh — плагинная система KeenTools.
# Менеджер ничего не знает о конкретных проектах: он находит модули
# в $KT_MODULES_DIR/*/info.json и управляет ими через стандартный набор
# скриптов: install.sh uninstall.sh start.sh stop.sh restart.sh update.sh status.sh

# ---------------------------------------------------------------------------
# Список всех модулей в каталоге (папка существует + есть info.json)
# ---------------------------------------------------------------------------
kt_module_list_all() {
    for d in "$KT_MODULES_DIR"/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        [ "$name" = "_template" ] && continue
        [ -f "${d}info.json" ] || continue
        echo "$name"
    done
}

kt_module_dir()  { echo "$KT_MODULES_DIR/$1"; }
kt_module_info_json() { echo "$(kt_module_dir "$1")/info.json"; }

kt_module_exists() {
    [ -f "$(kt_module_info_json "$1")" ]
}

# ---------------------------------------------------------------------------
# Чтение полей info.json (требует jq)
# kt_module_field <module> <jq-фильтр, напр. .name>
# ---------------------------------------------------------------------------
kt_module_field() {
    name="$1"; filter="$2"
    f=$(kt_module_info_json "$name")
    [ -f "$f" ] || { echo ""; return 1; }
    jq -r "$filter // empty" "$f" 2>/dev/null
}

kt_module_name()        { kt_module_field "$1" ".name"; }
kt_module_version()     { kt_module_field "$1" ".version"; }
kt_module_author()      { kt_module_field "$1" ".author"; }
kt_module_description() { kt_module_field "$1" ".description"; }
kt_module_homepage()    { kt_module_field "$1" ".homepage"; }
kt_module_update_url()  { kt_module_field "$1" ".update_url"; }

# Список зависимостей, по одной в строке
kt_module_dependencies() {
    f=$(kt_module_info_json "$1")
    [ -f "$f" ] || return 0
    jq -r '.dependencies[]? // empty' "$f" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Состояние установки: $KT_STATE_DIR/<module>/installed хранит версию
# ---------------------------------------------------------------------------
kt_state_file() { echo "$KT_STATE_DIR/$1/installed"; }

kt_module_is_installed() {
    [ -f "$(kt_state_file "$1")" ]
}

kt_module_installed_version() {
    sf=$(kt_state_file "$1")
    [ -f "$sf" ] && cat "$sf" || echo ""
}

kt_mark_installed() {
    name="$1"; ver="$2"
    mkdir -p "$KT_STATE_DIR/$name"
    echo "$ver" > "$(kt_state_file "$name")"
}

kt_mark_uninstalled() {
    rm -f "$(kt_state_file "$1")"
    rmdir "$KT_STATE_DIR/$1" 2>/dev/null
}

kt_module_list_installed() {
    for name in $(kt_module_list_all); do
        kt_module_is_installed "$name" && echo "$name"
    done
}

kt_module_list_available() {
    for name in $(kt_module_list_all); do
        kt_module_is_installed "$name" || echo "$name"
    done
}

# ---------------------------------------------------------------------------
# Запуск скрипта жизненного цикла модуля, если он существует
# kt_module_run <module> <script.sh> [args...]
# ---------------------------------------------------------------------------
kt_module_run() {
    name="$1"; script="$2"; shift 2
    path="$(kt_module_dir "$name")/$script"
    if [ ! -x "$path" ]; then
        if [ -f "$path" ]; then
            chmod +x "$path" 2>/dev/null
        else
            kt_warn "У модуля '$name' нет скрипта $script — пропускаю"
            return 2
        fi
    fi
    KT_HOME="$KT_HOME" KT_MODULE_DIR="$(kt_module_dir "$name")" "$path" "$@"
}

# ---------------------------------------------------------------------------
# Статус модуля. Соглашение о кодах возврата status.sh:
#   0 = запущен, 1 = остановлен (но установлен), 2 = ошибка/не определить
# ---------------------------------------------------------------------------
kt_module_status_code() {
    kt_module_run "$1" status.sh >/dev/null 2>&1
    echo $?
}

kt_module_status_dot() {
    if ! kt_module_is_installed "$1"; then
        kt_dot_unknown
        return
    fi
    code=$(kt_module_status_code "$1")
    case "$code" in
        0) kt_dot_running ;;
        1) kt_dot_stopped ;;
        *) kt_dot_unknown ;;
    esac
}

kt_module_status_text() {
    if ! kt_module_is_installed "$1"; then
        echo "не установлен"
        return
    fi
    code=$(kt_module_status_code "$1")
    case "$code" in
        0) echo "запущен" ;;
        1) echo "остановлен" ;;
        *) echo "неизвестно" ;;
    esac
}

# ---------------------------------------------------------------------------
# Установка / удаление / управление
# ---------------------------------------------------------------------------
kt_module_install() {
    name="$1"
    if ! kt_module_exists "$name"; then
        kt_err "Модуль '$name' не найден в каталоге"
        return 1
    fi
    if kt_module_is_installed "$name"; then
        kt_warn "Модуль '$name' уже установлен"
        return 0
    fi

    kt_check_dependencies "$name" || return 1

    kt_info "Установка модуля '$name'..."
    if kt_module_run "$name" install.sh; then
        ver=$(kt_module_version "$name")
        kt_mark_installed "$name" "$ver"
        kt_ok "Модуль '$name' установлен (версия $ver)"
        return 0
    else
        kt_err "Ошибка установки модуля '$name'"
        return 1
    fi
}

kt_module_uninstall() {
    name="$1"
    if ! kt_module_is_installed "$name"; then
        kt_warn "Модуль '$name' не установлен"
        return 0
    fi
    if kt_module_run "$name" uninstall.sh; then
        kt_mark_uninstalled "$name"
        kt_ok "Модуль '$name' удалён"
        return 0
    else
        kt_err "Ошибка удаления модуля '$name'"
        return 1
    fi
}

kt_module_start()   { kt_module_run "$1" start.sh   && kt_ok "'$1' запущен"   || kt_err "Не удалось запустить '$1'"; }
kt_module_stop()    { kt_module_run "$1" stop.sh    && kt_ok "'$1' остановлен" || kt_err "Не удалось остановить '$1'"; }
kt_module_restart() { kt_module_run "$1" restart.sh && kt_ok "'$1' перезапущен" || kt_err "Не удалось перезапустить '$1'"; }

kt_module_update() {
    name="$1"
    if ! kt_module_is_installed "$name"; then
        kt_warn "Модуль '$name' не установлен"
        return 1
    fi
    kt_info "Обновление модуля '$name'..."
    if kt_module_run "$name" update.sh; then
        ver=$(kt_module_version "$name")
        kt_mark_installed "$name" "$ver"
        kt_ok "Модуль '$name' обновлён до $ver"
    else
        kt_err "Ошибка обновления модуля '$name'"
        return 1
    fi
}
