#!/bin/sh
# log.sh — у MagiTrickle нет отдельного лог-файла: события смотрят во
# вкладке «Диагностика» веб-интерфейса. Как fallback показываем то,
# что попало в системный логгер (если он есть).
if command -v logread >/dev/null 2>&1; then
    logread 2>/dev/null | grep -i magitrickle | tail -n 50
    exit 0
fi

echo "Отдельный лог-файл MagiTrickle не найден."
echo "Смотрите вкладку «Диагностика» в веб-интерфейсе: http://<IP роутера>:8080"
