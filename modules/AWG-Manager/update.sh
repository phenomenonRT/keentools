#!/bin/sh
# update.sh — обновление awg-manager до последней версии.
# Повторный запуск установщика сам определит архитектуру и обновит пакет.
opkg update
wget -qO- http://repo.hoaxisr.ru/install.sh | sh
exit 0
