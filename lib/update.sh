#!/bin/sh
# update.sh — безопасное обновление KeenTools и модулей.
#
# По умолчанию менеджер обновляет сам себя прямо из GitHub-репозитория
# проекта (см. KT_GITHUB_* в lib/common.sh). Если задан KT_REPO_URL —
# используется он вместо GitHub для проверки VERSION/CHANGELOG.txt.
# Если основной GitHub недоступен, используются зеркала из
# KT_GITHUB_MIRRORS (settings.conf), по одному, пока одно не ответит.

# ---------------------------------------------------------------------------
# Зеркала: пробуем базовый URL, при неудаче — зеркала по очереди
# kt_fetch_with_mirrors <path-relative-to-raw-base> [max-time]
# echo содержимое, код возврата 0 при успехе
# ---------------------------------------------------------------------------
kt_mirror_list() {
    cfg=$(kt_config_get KT_GITHUB_MIRRORS)
    [ -n "$cfg" ] && echo "$cfg" | tr ',' '\n'
}

kt_fetch_with_mirrors() {
    rel_path="$1"; max_time="${2:-5}"
    base=$(kt_self_repo_base)
    out=$(curl -fsSL --max-time "$max_time" "$base/$rel_path" 2>/dev/null)
    if [ -n "$out" ]; then echo "$out"; return 0; fi

    for m in $(kt_mirror_list); do
        m="${m%/}"
        out=$(curl -fsSL --max-time "$max_time" "$m/$KT_GITHUB_OWNER/$KT_GITHUB_REPO/$KT_GITHUB_BRANCH/$rel_path" 2>/dev/null)
        [ -n "$out" ] && { echo "$out"; return 0; }
    done
    return 1
}

# Архив репозитория с fallback на зеркала
kt_download_archive_with_mirrors() {
    dest="$1"; max_time="${2:-60}"
    if curl -fsSL --max-time "$max_time" -o "$dest" "$KT_GITHUB_ARCHIVE_URL" 2>/dev/null && [ -s "$dest" ]; then
        return 0
    fi
    for m in $(kt_mirror_list); do
        m="${m%/}"
        if curl -fsSL --max-time "$max_time" -o "$dest" "$m/$KT_GITHUB_OWNER/$KT_GITHUB_REPO/archive/refs/heads/$KT_GITHUB_BRANCH.tar.gz" 2>/dev/null && [ -s "$dest" ]; then
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# NEW: проверка целостности keentools.sh — используется и при первичной
# установке (install.sh дублирует эту логику для bootstrap-случая, когда
# lib/ ещё не на месте), и здесь, при самообновлении. Признак настоящего
# файла менеджера — наличие определения главной функции меню и разумный
# размер (битый/усечённый файл или файл-обёртка будут значительно короче).
# ---------------------------------------------------------------------------
kt_verify_keentools_sh() {
    f="$1"
    [ -f "$f" ] || return 1
    grep -q 'kt_menu_main()' "$f" 2>/dev/null || return 1
    if grep -q 'KT_WRAPPER_ACTIVE' "$f" 2>/dev/null; then
        return 1
    fi
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    [ "$lines" -gt 50 ] 2>/dev/null || return 1
    return 0
}

# ---------------------------------------------------------------------------
# Обновление самого менеджера
# ---------------------------------------------------------------------------
kt_self_current_version() {
    [ -f "$KT_VERSION_FILE" ] && cat "$KT_VERSION_FILE" || echo "0.0.0"
}

# Базовый URL для проверки VERSION/CHANGELOG.txt: свой KT_REPO_URL,
# если задан в настройках, иначе — репозиторий проекта на GitHub.
kt_self_repo_base() {
    repo_url=$(kt_config_get KT_REPO_URL)
    [ -n "$repo_url" ] && echo "$repo_url" || echo "$KT_GITHUB_RAW_BASE"
}

kt_self_check_update() {
    remote_ver=$(kt_fetch_with_mirrors "VERSION" 5 | tr -d '[:space:]')
    [ -z "$remote_ver" ] && { kt_warn "Не удалось получить версию из репозитория (проверьте KT_REPO_URL/зеркала)"; return 1; }

    local_ver=$(kt_self_current_version)
    if kt_version_gt "$remote_ver" "$local_ver"; then
        echo "$remote_ver"
        return 0
    fi
    return 1
}

kt_self_update() {
    remote_ver="$1"

    kt_header "Обновление KeenTools"
    echo "Текущая версия:  $(kt_self_current_version)"
    echo "Новая версия:    $remote_ver"
    echo

    changelog=$(kt_fetch_with_mirrors "CHANGELOG.txt" 5)
    if [ -n "$changelog" ]; then
        echo "Список изменений:"
        echo "$changelog"
        echo
    fi

    kt_confirm "Обновить KeenTools до $remote_ver?" || { kt_info "Отменено"; return 1; }

    tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/kt_update.$$")
    mkdir -p "$tmp_dir"
    archive="$tmp_dir/keentools.tar.gz"

    kt_info "1/5 Проверка доступности новой версии... OK"

    kt_info "2/5 Загрузка архива репозитория ($KT_GITHUB_BRANCH)..."
    if ! kt_download_archive_with_mirrors "$archive" 60; then
        kt_err "Ошибка загрузки архива (GitHub и все зеркала недоступны)"
        rm -rf "$tmp_dir"
        return 1
    fi

    kt_info "3/5 Резервное копирование текущей версии..."
    backup_file=$(kt_backup_create)

    kt_info "4/5 Замена файлов..."
    if ! tar -xzf "$archive" -C "$tmp_dir" 2>/dev/null; then
        kt_err "Ошибка распаковки. Восстанавливаю предыдущую версию..."
        [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    extracted_dir=""
    for d in "$tmp_dir"/*; do
        if [ -d "$d" ]; then
            extracted_dir="$d"
            break
        fi
    done
    if [ -z "$extracted_dir" ] || [ ! -f "$extracted_dir/keentools.sh" ]; then
        kt_err "Неожиданная структура архива. Восстанавливаю предыдущую версию..."
        [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    # NEW: проверяем содержимое ДО того, как затирать рабочую установку —
    # если скачанный keentools.sh битый/неполный, лучше вообще не трогать
    # текущие файлы, чем заменить рабочую версию на нерабочую.
    if ! kt_verify_keentools_sh "$extracted_dir/keentools.sh"; then
        kt_err "Скачанный keentools.sh не прошёл проверку целостности. Обновление отменено, текущие файлы не тронуты."
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -f "$KT_HOME/keentools.sh"

    if ! cp -a "$extracted_dir"/* "$KT_HOME/" 2>/dev/null; then
        if ! cp -r "$extracted_dir"/* "$KT_HOME/" 2>/dev/null; then
            kt_err "Ошибка копирования файлов. Восстанавливаю предыдущую версию..."
            [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
            rm -rf "$tmp_dir"
            return 1
        fi
    fi

    for f in "$extracted_dir"/.*; do
        case "$f" in
            */. | */..) continue ;;
            *) [ -e "$f" ] && cp -a "$f" "$KT_HOME/" 2>/dev/null || true ;;
        esac
    done

    find "$KT_HOME" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

    if [ -d /opt/bin ]; then
        for cmd in keentools kt keenkit; do
            rm -f "/opt/bin/$cmd"
            cat > "/opt/bin/$cmd" << EOF
#!/bin/sh
if [ "\$KT_WRAPPER_ACTIVE" = "1" ]; then
    echo "[✘] Обнаружен рекурсивный запуск: $KT_HOME/keentools.sh, похоже, повреждён" >&2
    echo "    (содержит саму команду-обёртку вместо менеджера)." >&2
    echo "    Переустановите KeenTools:" >&2
    echo "      curl -fsSL https://raw.githubusercontent.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/refs/heads/${KT_GITHUB_BRANCH}/install.sh | sh" >&2
    exit 1
fi
KT_WRAPPER_ACTIVE=1 exec sh "$KT_HOME/keentools.sh" "\$@"
EOF
            chmod +x "/opt/bin/$cmd"
        done
    fi

    # NEW: финальная проверка уже установленного файла — на случай сбоя
    # на этапе cp, записи или создания обёрток. Если что-то пошло не так,
    # автоматически откатываемся на бэкап.
    if ! kt_verify_keentools_sh "$KT_HOME/keentools.sh"; then
        kt_err "После копирования keentools.sh повреждён. Автоматически восстанавливаю предыдущую версию..."
        if [ -n "$backup_file" ] && kt_backup_restore "$backup_file"; then
            kt_ok "Предыдущая версия восстановлена"
        else
            kt_err "Не удалось восстановить бэкап автоматически — переустановите KeenTools вручную:"
            kt_err "  curl -fsSL https://raw.githubusercontent.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/refs/heads/${KT_GITHUB_BRANCH}/install.sh | sh"
        fi
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"
    kt_ok "5/5 KeenTools обновлён до $remote_ver"
    kt_info "Перезапустите меню, чтобы применить обновление"
    return 0
}

# ---------------------------------------------------------------------------
# Обновление модулей
# ---------------------------------------------------------------------------
kt_module_check_update() {
    name="$1"
    url=$(kt_module_update_url "$name")
    [ -z "$url" ] && return 1

    remote_json=$(curl -fsSL --max-time 5 "$url" 2>/dev/null)
    [ -z "$remote_json" ] && return 1

    remote_ver=$(echo "$remote_json" | jq -r '.version // empty' 2>/dev/null)
    [ -z "$remote_ver" ] && return 1

    local_ver=$(kt_module_installed_version "$name")
    if kt_version_gt "$remote_ver" "$local_ver"; then
        echo "$remote_ver"
        return 0
    fi
    return 1
}

# Проверяет все установленные модули + себя. По умолчанию — "тихий/быстрый"
# режим (KT_CHECK_QUIET=yes): проверки модулей запускаются параллельно в
# фоне, печатается только итоговая сводка (что реально есть обновления).
kt_updates_available_list=""

kt_check_all_updates() {
    kt_header "Проверка обновлений"
    kt_updates_available_list=""
    found_any=0
    quiet=$(kt_config_get KT_CHECK_QUIET)
    [ "$quiet" != "no" ] && quiet=yes

    check_self=$(kt_config_get KT_CHECK_SELF_UPDATES)
    check_mods=$(kt_config_get KT_CHECK_MODULE_UPDATES)

    if [ "$check_self" != "no" ]; then
        self_new=$(kt_self_check_update 2>/dev/null)
        if [ -n "$self_new" ]; then
            printf "%b\342\234\224%b KeenTools %s \342\206\222 %s\n" "$C_GREEN" "$C_RESET" "$(kt_self_current_version)" "$self_new"
            found_any=1
        fi
    fi

    if [ "$check_mods" != "no" ]; then
        tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/kt_check.$$")
        mkdir -p "$tmp_dir"
        names=$(kt_module_list_installed)

        if [ "$quiet" = "yes" ]; then
            # Быстрый режим: проверяем модули параллельно в фоне
            for name in $names; do
                (
                    new_ver=$(kt_module_check_update "$name")
                    [ -n "$new_ver" ] && echo "$name|$new_ver" > "$tmp_dir/$name.result"
                ) &
            done
            wait
            for name in $names; do
                res="$tmp_dir/$name.result"
                if [ -f "$res" ]; then
                    new_ver=$(cut -d'|' -f2 "$res")
                    cur=$(kt_module_installed_version "$name")
                    printf "%b\342\234\224%b %s %s \342\206\222 %s\n" "$C_GREEN" "$C_RESET" "$(kt_module_name "$name")" "$cur" "$new_ver"
                    kt_updates_available_list="$kt_updates_available_list $name"
                    found_any=1
                fi
            done
            rm -rf "$tmp_dir"
        else
            # Подробный режим: последовательно, с построчным выводом
            for name in $names; do
                new_ver=$(kt_module_check_update "$name")
                if [ -n "$new_ver" ]; then
                    cur=$(kt_module_installed_version "$name")
                    printf "%b\342\234\224%b %s %s \342\206\222 %s\n" "$C_GREEN" "$C_RESET" "$(kt_module_name "$name")" "$cur" "$new_ver"
                    kt_updates_available_list="$kt_updates_available_list $name"
                    found_any=1
                else
                    printf "%b\342\200\224%b %s \342\200\224 актуальная версия\n" "$C_GRAY" "$C_RESET" "$(kt_module_name "$name")"
                fi
            done
        fi
    fi

    if [ "$found_any" = "0" ]; then
        kt_ok "Все компоненты актуальны"
        return 1
    fi
    return 0
}
