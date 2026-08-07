#!/bin/sh
# install.sh — установка KeenTools на роутер Keenetic с Entware.
#
# Вариант 1 (по ссылке, без ручного скачивания репозитория):
#   curl -fsSL https://raw.githubusercontent.com/phenomenonRT/keentools/refs/heads/main/install.sh | sh
#
# Вариант 2 (локально, если уже скачали/склонировали репозиторий):
#   cd keentools && sh install.sh
#
# В обоих случаях скрипт: проверяет Entware/opkg, ставит зависимости
# (curl, jq) через opkg, копирует файлы в /opt/etc/keentools, делает всё
# исполняемым и добавляет короткую команду "keentools".

set -e

# ---------------------------------------------------------------------------
# Репозиторий проекта на GitHub (используется, если скрипт запущен не из
# локальной копии, а как "curl ... | sh")
# ---------------------------------------------------------------------------
KT_GITHUB_OWNER="phenomenonRT"
KT_GITHUB_REPO="keentools"
KT_GITHUB_BRANCH="main"
KT_GITHUB_ARCHIVE_URL="https://github.com/${KT_GITHUB_OWNER}/${KT_GITHUB_REPO}/archive/refs/heads/${KT_GITHUB_BRANCH}.tar.gz"

TARGET="/opt/etc/keentools"

echo "================================"
echo " Установка KeenTools"
echo "================================"
echo

# ---------------------------------------------------------------------------
# Определяем режим: локальная копия рядом со скриптом или запуск "по ссылке"
# ---------------------------------------------------------------------------
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
# Проверка Entware
# ---------------------------------------------------------------------------
# if [ ! -x /opt/bin/opkg ] && ! command -v opkg >/dev/null 2>&1; then
#     echo "[✘] Entware/opkg не найден."
#     echo "    Сначала установите Entware: https://help.keenetic.com/hc/ru/articles/360021214160"
#     exit 1
# fi
# echo "[✔] Entware найден"

# ---------------------------------------------------------------------------
# Зависимости: curl нужен и для скачивания архива (в remote-режиме),
# и самому менеджеру (проверка обновлений и т.д.); jq — для чтения info.json
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
    read -r ans
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
# Remote-режим: скачиваем архив ветки с GitHub и распаковываем во временную папку
# ---------------------------------------------------------------------------
if [ "$MODE" = "remote" ]; then
    tmp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/keentools_install.$$")
    mkdir -p "$tmp_dir"
    archive="$tmp_dir/keentools.tar.gz"

    echo "[i] Скачивание $KT_GITHUB_ARCHIVE_URL ..."
    if ! curl -fsSL -o "$archive" "$KT_GITHUB_ARCHIVE_URL"; then
        echo "[✘] Не удалось скачать архив репозитория"
        rm -rf "$tmp_dir"
        exit 1
    fi

    echo "[i] Распаковка..."
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        echo "[✘] Не удалось распаковать архив"
        rm -rf "$tmp_dir"
        exit 1
    fi

    # Архив GitHub всегда содержит ровно одну папку вида <repo>-<branch>
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
# Копирование файлов в целевую директорию
# ---------------------------------------------------------------------------
if [ -d "$TARGET" ] && [ "$SRC_DIR" != "$TARGET" ]; then
    echo "[i] Найдена существующая установка в $TARGET — обновляю файлы (state/config сохранятся)"
fi

mkdir -p "$TARGET"
cp -a "$SRC_DIR/." "$TARGET/" 2>/dev/null || true

chmod +x "$TARGET/keentools.sh"
find "$TARGET" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "[✔] Файлы установлены в $TARGET"

# ---------------------------------------------------------------------------
# Уборка временных файлов (remote-режим)
# ---------------------------------------------------------------------------
if [ "$MODE" = "remote" ]; then
    rm -rf "$tmp_dir"
fi

# ---------------------------------------------------------------------------
# Короткая команда запуска
# ---------------------------------------------------------------------------
# ВАЖНО: делаем именно обёрточный скрипт с абсолютным путём, а не симлинк.
# keentools.sh вычисляет свою директорию через dirname "$0", а dirname не
# разворачивает символические ссылки — при вызове через симлинк /opt/bin/keentools
# скрипт получил бы "$0"=/opt/bin/keentools и искал бы lib/ в /opt/bin/lib,
# которого не существует.
if [ -d /opt/bin ]; then
    cat > /opt/bin/keentools << EOF
#!/bin/sh
exec sh "$TARGET/keentools.sh" "\$@"
EOF
    chmod +x /opt/bin/keentools
    echo "[✔] Добавлена команда: keentools"
else
    echo "[i] /opt/bin не найден — запускайте так: sh $TARGET/keentools.sh"
fi

echo
echo "Готово! Запустите менеджер командой:"
echo "  keentools"
echo "(или: sh $TARGET/keentools.sh)"
