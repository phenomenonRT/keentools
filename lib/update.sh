#!/bin/sh
# update.sh — безопасное обновление KeenTools и модулей.
#
# По умолчанию менеджер обновляет сам себя прямо из GitHub-репозитория
# проекта (см. KT_GITHUB_* в lib/common.sh) — отдельно хостить релизы
# не нужно:
#   <KT_GITHUB_RAW_BASE>/VERSION        — версия в репозитории
#   <KT_GITHUB_RAW_BASE>/CHANGELOG.txt  — список изменений (опционально)
#   <KT_GITHUB_ARCHIVE_URL>             — архив ветки целиком (codeload)
#
# Если в settings.conf указан свой KT_REPO_URL — используется он вместо
# GitHub для проверки VERSION/CHANGELOG.txt (например, для приватного
# зеркала), но сам архив всё равно берётся с GitHub, так как раздать
# архив всего репозитория через "сырые" файлы нельзя.
#
# Для модулей используется поле "update_url" в info.json, указывающее
# на аналогичный remote info.json с актуальной версией.

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
    base=$(kt_self_repo_base)
    remote_ver=$(curl -fsSL --max-time 5 "$base/VERSION" 2>/dev/null | tr -d '[:space:]')
    [ -z "$remote_ver" ] && { kt_warn "Не удалось получить версию из репозитория ($base)"; return 1; }

    local_ver=$(kt_self_current_version)
    if kt_version_gt "$remote_ver" "$local_ver"; then
        echo "$remote_ver"
        return 0
    fi
    return 1
}

kt_self_update() {
    base=$(kt_self_repo_base)
    remote_ver="$1"

    kt_header "Обновление KeenTools"
    echo "Текущая версия:  $(kt_self_current_version)"
    echo "Новая версия:    $remote_ver"
    echo

    changelog=$(curl -fsSL --max-time 5 "$base/CHANGELOG.txt" 2>/dev/null)
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

    kt_info "2/5 Загрузка архива репозитория ($KT_GITHUB_BRANCH) с GitHub..."
    if ! curl -fsSL --max-time 60 -o "$archive" "$KT_GITHUB_ARCHIVE_URL"; then
        kt_err "Ошибка загрузки $KT_GITHUB_ARCHIVE_URL"
        rm -rf "$tmp_dir"
        return 1
    fi
    # GitHub codeload отдаёт архив по HTTPS без отдельной контрольной суммы —
    # целостность обеспечивается самим TLS-соединением к github.com,
    # аналогично тому, как устанавливается сам install.sh через curl|sh.

    kt_info "3/5 Резервное копирование текущей версии..."
    backup_file=$(kt_backup_create)

    kt_info "4/5 Замена файлов..."
    if ! tar -xzf "$archive" -C "$tmp_dir" 2>/dev/null; then
        kt_err "Ошибка распаковки. Восстанавливаю предыдущую версию..."
        [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    # GitHub-архив всегда содержит ровно одну папку вида <repo>-<branch>
    extracted_dir=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [ -z "$extracted_dir" ] || [ ! -f "$extracted_dir/keentools.sh" ]; then
        kt_err "Неожиданная структура архива. Восстанавливаю предыдущую версию..."
        [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    if ! cp -a "$extracted_dir/." "$KT_HOME/" 2>/dev/null; then
        kt_err "Ошибка копирования файлов. Восстанавливаю предыдущую версию..."
        [ -n "$backup_file" ] && kt_backup_restore "$backup_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    find "$KT_HOME" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

    rm -rf "$tmp_dir"
    kt_ok "5/5 KeenTools обновлён до $remote_ver"
    kt_info "Перезапустите меню, чтобы применить обновление"
    return 0
}

# ---------------------------------------------------------------------------
# Обновление модулей
# ---------------------------------------------------------------------------
kt_module_check_update() {
    # echo новую версию, если она есть; иначе ничего не выводит и код возврата 1
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

# Проверяет все установленные модули, печатает сводку, возвращает
# список модулей с обновлениями (по одному в строке) через глобальную переменную
kt_updates_available_list=""

kt_check_all_updates() {
    kt_header "Проверка обновлений"
    kt_updates_available_list=""
    found_any=0

    check_self=$(kt_config_get KT_CHECK_SELF_UPDATES)
    check_mods=$(kt_config_get KT_CHECK_MODULE_UPDATES)

    if [ "$check_self" != "no" ]; then
        self_new=$(kt_self_check_update)
        if [ -n "$self_new" ]; then
            printf "%b\342\234\224%b KeenTools %s \342\206\222 %s\n" "$C_GREEN" "$C_RESET" "$(kt_self_current_version)" "$self_new"
            found_any=1
        fi
    fi

    if [ "$check_mods" != "no" ]; then
        for name in $(kt_module_list_installed); do
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

    if [ "$found_any" = "0" ]; then
        kt_ok "Все компоненты актуальны"
        return 1
    fi
    return 0
}
