#!/bin/sh
set -e
opkg update && opkg upgrade
wget -qO- http://repo.hoaxisr.ru/install.sh | sh
echo "AWG Manager установлен."
exit 0
