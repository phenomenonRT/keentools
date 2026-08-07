#!/bin/sh
# common.sh — общие функции KeenTools
# POSIX/ash-совместимо (BusyBox ash на Keenetic/Entware), без bashизмов.

# ---------------------------------------------------------------------------
# Пути
# ---------------------------------------------------------------------------
: "${KT_HOME:=/opt/etc/keentools}"
KT_MODULES_DIR="$KT_HOME/modules"
KT_STATE_DIR="$KT_HOME/state"
KT_CONFIG_DIR="$KT_HOME/config"
KT_CONFIG_FILE="$KT_CONFIG_DIR/settings.conf"
KT_BACKUP_DIR="$KT_HOME/backups"
KT_LOG_DIR="$KT_HOME/logs"
KT_LOG_FILE="$KT_LOG_DIR/keentools.log"
KT_VERSION_FILE="$KT_HOME/VERSION"

# ---------------------------------------------------------------------------
# Домашний репозиторий проекта на GitHub.
# Используется установщиком (install.sh) и самообновлением (lib/update.sh)
# "из коробки", без необходимости хостить отдельно релизные архивы.
# ---------------------------------------------------------------------------
: "${KT_GITHUB_OWNER:=phenomenonRT}"
: "${KT_GITHUB_REPO:=keentools}"
: "${KT_GITHUB_BRANCH:=main}"
KT_GITHUB_RAW_BASE="https://raw.githubusercontent.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/refs/heads/${KT_GITHUB_BRANCH}"
KT_GITHUB_ARCHIVE_URL="https://github.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/archive/refs/heads/${KT_GITHUB_BRANCH}.tar.gz"

# ---------------------------------------------------------------------------
# Цвета (можно отключить в settings.conf: KT_NO_COLOR=1)
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ "$KT_NO_COLOR" != "1" ]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_CYAN='\033[36m'
    C_GRAY='\033[90m'
else
    C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_GRAY=''
fi

kt_dot_running() { printf "%b\342\227\217%b" "$C_GREEN" "$C_RESET"; }   # ● зелёный
kt_dot_stopped() { printf "%b\342\227\213%b" "$C_RED" "$C_RESET"; }    # ○ красный
kt_dot_unknown() { printf "%b\342\227\217%b" "$C_GRAY" "$C_RESET"; }   # ● серый

# ---------------------------------------------------------------------------
# Вывод / логирование
# ---------------------------------------------------------------------------
kt_log() {
    # kt_log LEVEL message
    lvl="$1"; shift
    mkdir -p "$KT_LOG_DIR" 2>/dev/null
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$lvl" "$*" >> "$KT_LOG_FILE" 2>/dev/null
}

# ВАЖНО: все эти функции пишут в stderr, а не в stdout. Многие функции
# библиотеки (kt_backup_create, kt_self_check_update и т.д.) возвращают
# значение через "echo" и вызываются как `x=$(kt_some_func)` — если бы
# kt_info/kt_ok/kt_warn писали в stdout, их текст попадал бы в переменную
# вместе с реальным результатом. В интерактивном терминале stdout и stderr
# всё равно выводятся вместе, так что для пользователя ничего не меняется.
kt_info()  { printf "%b[i]%b %s\n" "$C_BLUE" "$C_RESET" "$*" >&2; kt_log INFO "$*"; }
kt_ok()    { printf "%b[\342\234\224]%b %s\n" "$C_GREEN" "$C_RESET" "$*" >&2; kt_log OK "$*"; }
kt_warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; kt_log WARN "$*"; }
kt_err()   { printf "%b[\342\234\230]%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; kt_log ERROR "$*"; }

kt_header() {
    printf "%b================================%b\n" "$C_CYAN" "$C_RESET"
    printf "%b %s%b\n" "$C_BOLD" "$*" "$C_RESET"
    printf "%b================================%b\n" "$C_CYAN" "$C_RESET"
}

kt_line() { printf "%b--------------------------------%b\n" "$C_GRAY" "$C_RESET"; }

# ---------------------------------------------------------------------------
# Ввод пользователя
# ---------------------------------------------------------------------------
kt_confirm() {
    # kt_confirm "Вопрос?" -> 0 = да, 1 = нет
    q="$1"
    while true; do
        printf "%s [Y/N]: " "$q"
        read -r ans
        case "$ans" in
            [YyДд]*) return 0 ;;
            [NnНн]*) return 1 ;;
            *) printf "Введите Y или N\n" ;;
        esac
    done
}

kt_pause() {
    printf "\nНажмите Enter для продолжения..."
    read -r _
}

# ---------------------------------------------------------------------------
# Проверки утилит
# ---------------------------------------------------------------------------
kt_has_cmd() { command -v "$1" >/dev/null 2>&1; }

kt_require_jq() {
    if ! kt_has_cmd jq; then
        kt_err "Требуется jq, но он не установлен. Установите: opkg install jq"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Сравнение версий вида X.Y.Z (произвольное число сегментов)
# Возвращает через echo: gt | lt | eq
# ---------------------------------------------------------------------------
kt_version_compare() {
    v1="$1"; v2="$2"
    while [ -n "$v1" ] || [ -n "$v2" ]; do
        p1="${v1%%.*}"
        p2="${v2%%.*}"
        if [ "$p1" = "$v1" ]; then v1=""; else v1="${v1#*.}"; fi
        if [ "$p2" = "$v2" ]; then v2=""; else v2="${v2#*.}"; fi
        [ -z "$p1" ] && p1=0
        [ -z "$p2" ] && p2=0
        case "$p1" in *[!0-9]*) p1=0 ;; esac
        case "$p2" in *[!0-9]*) p2=0 ;; esac
        if [ "$p1" -gt "$p2" ] 2>/dev/null; then echo gt; return 0; fi
        if [ "$p1" -lt "$p2" ] 2>/dev/null; then echo lt; return 0; fi
    done
    echo eq
}

kt_version_gt() { [ "$(kt_version_compare "$1" "$2")" = "gt" ]; }

# ---------------------------------------------------------------------------
# Инициализация дерева каталогов (идемпотентно)
# ---------------------------------------------------------------------------
kt_init_dirs() {
    mkdir -p "$KT_MODULES_DIR" "$KT_STATE_DIR" "$KT_CONFIG_DIR" \
             "$KT_BACKUP_DIR" "$KT_LOG_DIR" 2>/dev/null
}
