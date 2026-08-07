#!/bin/sh
# backup.sh — резервное копирование состояния/конфигурации KeenTools и модулей.
# В бэкап попадают: state/ config/ modules/*/info.json и (если модуль их создаёт)
# любые файлы в modules/<name>/data/ — соглашение для модулей, хранящих
# пользовательские настройки рядом с собой.

kt_backup_create() {
    kt_init_dirs
    ts=$(date '+%Y%m%d_%H%M%S')
    out="$KT_BACKUP_DIR/keentools_backup_${ts}.tar.gz"

    kt_info "Создание резервной копии..."
    tmp_list=$(mktemp 2>/dev/null || echo "/tmp/kt_backup_list.$$")

    (
        cd "$KT_HOME" || exit 1
        [ -d state ]  && echo "state"
        [ -d config ] && echo "config"
        [ -f VERSION ] && echo "VERSION"
        for d in modules/*/; do
            [ -d "$d" ] || continue
            [ -f "${d}info.json" ] && echo "${d}info.json"
            [ -d "${d}data" ] && echo "${d}data"
        done
    ) > "$tmp_list"

    if [ ! -s "$tmp_list" ]; then
        kt_warn "Нечего резервировать"
        rm -f "$tmp_list"
        return 1
    fi

    if tar -czf "$out" -C "$KT_HOME" -T "$tmp_list" 2>/dev/null; then
        rm -f "$tmp_list"
        kt_ok "Резервная копия создана: $out"
        echo "$out"
        return 0
    else
        rm -f "$tmp_list"
        kt_err "Не удалось создать резервную копию"
        return 1
    fi
}

kt_backup_list() {
    [ -d "$KT_BACKUP_DIR" ] || return 0
    ls -1t "$KT_BACKUP_DIR"/keentools_backup_*.tar.gz 2>/dev/null
}

kt_backup_restore() {
    file="$1"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        kt_err "Файл резервной копии не найден: $file"
        return 1
    fi
    if ! kt_confirm "Восстановить из '$file'? Текущие настройки будут перезаписаны"; then
        kt_info "Восстановление отменено"
        return 1
    fi
    # Подстраховка: бэкапим текущее состояние перед восстановлением
    kt_backup_create >/dev/null 2>&1

    if tar -xzf "$file" -C "$KT_HOME" 2>/dev/null; then
        kt_ok "Восстановлено из '$file'"
        return 0
    else
        kt_err "Ошибка восстановления"
        return 1
    fi
}
