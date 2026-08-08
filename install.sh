#!/bin/sh
# install.sh — установка KeenTools на роутер Keenetic с Entware.
#
# Вариант 1 (по ссылке, без ручного скачивания репозитория):
#   curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keentools/refs/heads/main/install.sh | sh
#
# Вариант 2 (локально, если уже скачали/склонировали репозиторий):
#   cd keentools && sh install.sh
#
# Скрипт: спрашивает источник установки (GitHub или своё зеркало),
# проверяет Entware/opkg, ставит зависимости (curl, jq) через opkg,
# копирует файлы в /opt/etc/keentools, делает всё исполняемым и
# добавляет команды-алиасы: keentools, kt, keenkit.

set -e

KT_GITHUB_OWNER="phenomenonRT"
KT_GITHUB_REPO="keentools"
KT_GITHUB_BRANCH="main"
KT_GITHUB_ARCHIVE_URL="https://github.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/archive/refs/heads/${KT_GITHUB_BRANCH}.tar.gz"

TARGET="/opt/etc/keentools"

echo "================================"
echo " Установка KeenTools"
echo "================================"
echo

kt_read() {
    if [ -t 0 ]; then
        read -r "$1"
    elif [ -c /dev/tty ] && [ -r /dev/tty ]; then
        read -r "$1" < /dev/tty 2>/dev/null || eval "$1=''"
    else
        eval "$1=''"
    fi
}

CALLER_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)

if [ -f "$0" ] && [ -f "$CALLER_DIR/keentools.sh" ] && [ -d "$CALLER_DIR/lib" ]; then
    MODE="local"
    SRC_DIR="$CALLER_DIR"
    echo "[i] Обнаружена локальная копия проекта: $SRC_DIR"
else
    MODE="remote"
    echo "[i] Локальная копия не найдена — скачаю проект с GitHub"
fi

# ---------------------------------------------------------------------------
# Выбор источника установки (только для remote-режима: скачивания архива)
# ---------------------------------------------------------------------------
KT_MIRRORS=""
if [ "$MODE" = "remote" ]; then
    echo
    echo "Источник установки:"
    echo "  1) GitHub (по умолчанию)"
    echo "  2) Своё зеркало / прокси"
    printf "Выбор [1]: "
    kt_read src_choice
    if [ "$src_choice" = "2" ]; then
        printf "Введите базовый URL зеркала (например https://ghproxy.com): "
        kt_read mirror_url
        mirror_url="${mirror_url%/}"
        if [ -n "$mirror_url" ]; then
            KT_GITHUB_ARCHIVE_URL="${mirror_url}/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/archive/refs/heads/${KT_GITHUB_BRANCH}.tar.gz"
            KT_MIRRORS="$mirror_url"
            echo "[i] Буду качать через зеркало: $mirror_url"
        else
            echo "[i] Зеркало не указано — использую GitHub"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Зависимости
# ---------------------------------------------------------------------------
missing=""
for dep in curl jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        missing="$missing $dep"
    fi
done

if [ -n "$missing" ]; then
    echo "Не найдены пакеты:$missing"
    printf "Установить сейчас через opkg? [Y/N]: "
    kt_read ans
    case "$ans" in
        [YyДд]*)
            opkg update
            for dep in $missing; do
                opkg install "$dep"
            done
            ;;
        *)
            echo "Установка прервана: нужны эти зависимости."
            exit 1
            ;;
    esac
fi
echo "[✔] Зависимости на месте (curl, jq)"

# ---------------------------------------------------------------------------
# Remote-режим: скачиваем архив ветки (GitHub либо выбранное зеркало)
# ---------------------------------------------------------------------------
if [ "$MODE" = "remote" ]; then
    tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/keentools_install.$$")
    mkdir -p "$tmp_dir"
    archive="$tmp_dir/keentools.tar.gz"

    echo "[i] Скачивание $KT_GITHUB_ARCHIVE_URL ..."
    if ! curl -fsSL -o "$archive" "$KT_GITHUB_ARCHIVE_URL"; then
        echo "[✘] Не удалось скачать архив с выбранного источника"
        if [ -n "$KT_MIRRORS" ]; then
            echo "[i] Пробую напрямую с GitHub как резервный вариант..."
            fallback_url="https://github.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/archive/refs/heads/${KT_GITHUB_BRANCH}.tar.gz"
            if ! curl -fsSL -o "$archive" "$fallback_url"; then
                echo "[✘] GitHub тоже недоступен"
                rm -rf "$tmp_dir"
                exit 1
            fi
        else
            rm -rf "$tmp_dir"
            exit 1
        fi
    fi

    echo "[i] Распаковка..."
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        echo "[✘] Не удалось распаковать архив"
        rm -rf "$tmp_dir"
        exit 1
    fi

    extracted_dir=""
    for d in "$tmp_dir"/*; do
        if [ -d "$d" ]; then
            extracted_dir="$d"
            break
        fi
    done
    if [ -z "$extracted_dir" ] || [ ! -f "$extracted_dir/keentools.sh" ]; then
        echo "[✘] Неожиданная структура архива — не нашёл keentools.sh"
        rm -rf "$tmp_dir"
        exit 1
    fi

    SRC_DIR="$extracted_dir"
    echo "[✔] Проект скачан и распакован"
fi

# ---------------------------------------------------------------------------
# NEW: проверка целостности исходника ПЕРЕД копированием поверх установки.
# Защищает от ситуации, когда keentools.sh в источнике битый, усечённый
# или (по ошибке/багу где-то в цепочке) содержит не сам менеджер, а,
# например, текст скрипта-обёртки. Признак настоящего файла — наличие
# определения главной функции меню.
# ---------------------------------------------------------------------------
kt_verify_source_keentools_sh() {
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

if ! kt_verify_source_keentools_sh "$SRC_DIR/keentools.sh"; then
    echo "[✘] keentools.sh в источнике выглядит повреждённым или неполным — установка остановлена,"
    echo "    чтобы не испортить рабочую копию. Ничего не менялось."
    [ "$MODE" = "remote" ] && rm -rf "$tmp_dir"
    exit 1
fi

# ---------------------------------------------------------------------------
# Копирование файлов
# ---------------------------------------------------------------------------
if [ -d "$TARGET" ] && [ "$SRC_DIR" != "$TARGET" ]; then
    echo "[i] Найдена существующая установка в $TARGET — обновляю файлы (state/config сохранятся)"
fi

mkdir -p "$TARGET"
rm -f "$TARGET/keentools.sh"

if ! cp -a "$SRC_DIR"/* "$TARGET/" 2>/dev/null; then
    if ! cp -r "$SRC_DIR"/* "$TARGET/"; then
        echo "[✘] Ошибка копирования файлов в $TARGET"
        [ "$MODE" = "remote" ] && rm -rf "$tmp_dir"
        exit 1
    fi
fi

for f in "$SRC_DIR"/.*; do
    case "$f" in
        */. | */..) continue ;;
        *) [ -e "$f" ] && cp -a "$f" "$TARGET/" 2>/dev/null || true ;;
    esac
done

chmod +x "$TARGET/keentools.sh"
find "$TARGET" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Сохраняем выбранное зеркало в настройки, чтобы им пользовалось и самообновление
if [ -n "$KT_MIRRORS" ]; then
    mkdir -p "$TARGET/config"
    if [ -f "$TARGET/config/settings.conf" ] && grep -q "^KT_GITHUB_MIRRORS=" "$TARGET/config/settings.conf" 2>/dev/null; then
        tmp_cfg="$TARGET/config/settings.conf.tmp"
        awk -F'=' -v v="$KT_MIRRORS" 'BEGIN{OFS="="} $1=="KT_GITHUB_MIRRORS"{$0="KT_GITHUB_MIRRORS="v} {print}' \
            "$TARGET/config/settings.conf" > "$tmp_cfg" && mv "$tmp_cfg" "$TARGET/config/settings.conf"
    fi
fi

echo "[✔] Файлы установлены в $TARGET"

if [ "$MODE" = "remote" ]; then
    rm -rf "$tmp_dir"
fi

# ---------------------------------------------------------------------------
# Команды запуска: keentools, kt (короткий алиас), keenkit (алиас на
# случай, если удобнее ассоциировать команду не с "инструментами", а с
# "набором" проектов — оба указывают на один и тот же keentools.sh)
#
# NEW: обёртка защищена от бесконечной рекурсии переменной-флагом
# KT_WRAPPER_ACTIVE. Перед записью обёртки старый файл/симлинк удаляется
# через rm -f, чтобы 'cat >' не перезаписывал целевой keentools.sh по симлинку.
# ---------------------------------------------------------------------------
if [ -d /opt/bin ]; then
    for cmd in keentools kt keenkit; do
        rm -f "/opt/bin/$cmd"
        cat > "/opt/bin/$cmd" << EOF
#!/bin/sh
if [ "\$KT_WRAPPER_ACTIVE" = "1" ]; then
    echo "[✘] Обнаружен рекурсивный запуск: $TARGET/keentools.sh, похоже, повреждён" >&2
    echo "    (содержит саму команду-обёртку вместо менеджера)." >&2
    echo "    Переустановите KeenTools:" >&2
    echo "      curl -fsSL https://raw.githubusercontent.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/refs/heads/${KT_GITHUB_BRANCH}/install.sh | sh" >&2
    exit 1
fi
KT_WRAPPER_ACTIVE=1 exec sh "$TARGET/keentools.sh" "\$@"
EOF
        chmod +x "/opt/bin/$cmd"
    done
    echo "[✔] Добавлены команды: keentools, kt, keenkit"
else
    echo "[i] /opt/bin не найден — запускайте так: sh $TARGET/keentools.sh"
fi

# ---------------------------------------------------------------------------
# NEW: проверка целостности ПОСЛЕ копирования и создания обёрток.
# ---------------------------------------------------------------------------
if ! kt_verify_source_keentools_sh "$TARGET/keentools.sh"; then
    echo "[✘] После установки файл $TARGET/keentools.sh не прошёл проверку целостности."
    echo "    Установка НЕ завершена корректно. Не запускайте keentools/kt в этом состоянии."
    echo "    Повторите установку заново:"
    echo "      curl -fsSL https://raw.githubusercontent.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/refs/heads/${KT_GITHUB_BRANCH}/install.sh | sh"
    exit 1
fi

echo
echo "Готово! Запустите менеджер любой из команд:"
echo "  keentools   /   kt   /   keenkit"
echo "(или: sh $TARGET/keentools.sh)"

