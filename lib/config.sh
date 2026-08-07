#!/bin/sh
# config.sh — простое key=value хранилище настроек ($KT_CONFIG_FILE).

kt_config_ensure() {
    mkdir -p "$KT_CONFIG_DIR"
    if [ ! -f "$KT_CONFIG_FILE" ]; then
        cat > "$KT_CONFIG_FILE" <<'EOF'
# Настройки KeenTools. Формат: KEY=value

# URL своего репозитория для проверки VERSION/CHANGELOG.txt при
# самообновлении менеджера. Пусто = использовать GitHub-репозиторий
# проекта по умолчанию (KT_GITHUB_OWNER/KT_GITHUB_REPO/KT_GITHUB_BRANCH
# из lib/common.sh) — обычно менять не нужно.
KT_REPO_URL=

# Проверять обновления при запуске: yes/no
KT_CHECK_ON_START=yes

# Периодичность автопроверки: always | daily | weekly | never
KT_CHECK_FREQUENCY=daily

# Проверять обновления модулей: yes/no
KT_CHECK_MODULE_UPDATES=yes

# Проверять обновления самого менеджера: yes/no
KT_CHECK_SELF_UPDATES=yes

# Отключить цветной вывод: 1 = да
KT_NO_COLOR=0

# Отметка времени последней проверки обновлений (unix timestamp)
KT_LAST_CHECK_TS=0
EOF
    fi
}

kt_config_get() {
    key="$1"
    kt_config_ensure
    val=$(grep -E "^${key}=" "$KT_CONFIG_FILE" 2>/dev/null | tail -n1 | cut -d'=' -f2-)
    echo "$val"
}

kt_config_set() {
    key="$1"; value="$2"
    kt_config_ensure
    if grep -qE "^${key}=" "$KT_CONFIG_FILE" 2>/dev/null; then
        tmp="${KT_CONFIG_FILE}.tmp"
        awk -F'=' -v k="$key" -v v="$value" '
            BEGIN{OFS="="}
            $1==k {$0=k"="v}
            {print}
        ' "$KT_CONFIG_FILE" > "$tmp" && mv "$tmp" "$KT_CONFIG_FILE"
    else
        echo "${key}=${value}" >> "$KT_CONFIG_FILE"
    fi
}

# Нужно ли сейчас автоматически проверять обновления, согласно частоте
kt_should_autocheck() {
    kt_config_ensure
    on=$(kt_config_get KT_CHECK_ON_START)
    [ "$on" = "yes" ] || return 1

    freq=$(kt_config_get KT_CHECK_FREQUENCY)
    now=$(date +%s)
    last=$(kt_config_get KT_LAST_CHECK_TS)
    [ -z "$last" ] && last=0

    case "$freq" in
        always) return 0 ;;
        never)  return 1 ;;
        daily)  limit=86400 ;;
        weekly) limit=604800 ;;
        *)      limit=86400 ;;
    esac

    diff=$((now - last))
    [ "$diff" -ge "$limit" ]
}

kt_mark_checked_now() {
    kt_config_set KT_LAST_CHECK_TS "$(date +%s)"
}
