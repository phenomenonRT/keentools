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

# ---------------------------------------------------------------------------
# При запуске через "curl ... | sh" stdin самого sh — это уже байты
# скрипта, а не терминал пользователя. Обычный "read" в этом случае
# читает не ввод с клавиатуры, а хвост самого скрипта, что портит его
# дальнейший разбор ("unexpected done" и т.п.). Поэтому весь интерактивный
# ввод читаем напрямую из /dev/tty; если tty недоступен (неинтерактивный
# запуск, cron, CI) — используем безопасное значение по умолчанию.
# kt_read_tty <var_name> <default_value>
# ---------------------------------------------------------------------------
kt_read_tty() {
    var_name="$1"; default_val="$2"
    if [ -e /dev/tty ]; then
        read -r "$var_name" < /dev/tty
    else
        echo "[i] Нет доступного терминала — использую значение по умолчанию: $default_val"
        eval "$var_name=\"\$default_val\""
    fi
}

echo "================================"
echo " Установка KeenTools"
echo "================================"
echo

CALLER_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd || pwd)

if [ -f "$CALLER_DIR/keentools.sh" ] && [ -d "$CALLER_DIR/lib" ]; then
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
    kt_read_tty src_choice "1"
    if [ "$src_choice" = "2" ]; then
        printf "Введите базовый URL зеркала (например https://ghproxy.com): "
        kt_read_tty mirror_url ""
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
    kt_read_tty ans "Y"
    case "$ans" in
        [Yy]*)
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

    extracted_dir=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
    if [ -z "$extracted_dir" ] || [ ! -f "$extracted_dir/keentools.sh" ]; then
        echo "[✘] Неожиданная структура архива — не нашёл keentools.sh"
        rm -rf "$tmp_dir"
        exit 1
    fi

    SRC_DIR="$extracted_dir"
    echo "[✔] Проект скачан и распакован"
fi

# ---------------------------------------------------------------------------
# Копирование файлов
# ---------------------------------------------------------------------------
if [ -d "$TARGET" ] && [ "$SRC_DIR" != "$TARGET" ]; then
    echo "[i] Найдена существующая установка в $TARGET — обновляю файлы (state/config сохранятся)"
fi

mkdir -p "$TARGET"
cp -a "$SRC_DIR/." "$TARGET/" 2>/dev/null || true

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
# ---------------------------------------------------------------------------
if [ -d /opt/bin ]; then
    for cmd in keentools kt keenkit; do
        cat > "/opt/bin/$cmd" << EOF
#!/bin/sh
exec sh "$TARGET/keentools.sh" "\$@"
EOF
        chmod +x "/opt/bin/$cmd"
    done
    echo "[✔] Добавлены команды: keentools, kt, keenkit"
else
    echo "[i] /opt/bin не найден — запускайте так: sh $TARGET/keentools.sh"
fi

echo
echo "Готово! Запустите менеджер любой из команд:"
echo "  keentools   /   kt   /   keenkit"
echo "(или: sh $TARGET/keentools.sh)"
