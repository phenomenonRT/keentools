#!/bin/sh
# deps.sh — проверка зависимостей перед установкой модуля.

# Определить, доступна ли зависимость: либо как бинарь в PATH,
# либо как установленный opkg-пакет.
kt_dep_satisfied() {
    dep="$1"
    kt_has_cmd "$dep" && return 0
    if kt_has_cmd opkg; then
        opkg list-installed 2>/dev/null | grep -q "^${dep} " && return 0
    fi
    return 1
}

kt_dep_install() {
    dep="$1"
    kt_has_cmd opkg || { kt_err "opkg не найден, не могу установить '$dep' автоматически"; return 1; }
    opkg update >/dev/null 2>&1
    opkg install "$dep"
}

# kt_check_dependencies <module>
# Показывает список зависимостей с отметками, предлагает поставить недостающие.
kt_check_dependencies() {
    name="$1"
    deps=$(kt_module_dependencies "$name")
    [ -z "$deps" ] && return 0

    kt_info "Проверка зависимостей для '$name'..."
    missing=""
    for dep in $deps; do
        if kt_dep_satisfied "$dep"; then
            printf "  %b\342\234\224%b %s\n" "$C_GREEN" "$C_RESET" "$dep"
        else
            printf "  %b\342\234\230%b %s\n" "$C_RED" "$C_RESET" "$dep"
            missing="$missing $dep"
        fi
    done

    [ -z "$missing" ] && return 0

    echo
    if kt_confirm "Установить отсутствующие зависимости:$missing ?"; then
        for dep in $missing; do
            kt_info "Установка $dep..."
            if kt_dep_install "$dep"; then
                kt_ok "$dep установлен"
            else
                kt_err "Не удалось установить $dep"
                return 1
            fi
        done
        return 0
    else
        kt_warn "Установка отменена: не хватает зависимостей"
        return 1
    fi
}
