#!/bin/sh
opkg update && opkg install curl && curl -Ls "https://git.zerrolabs.org/Ground-Zerro/release/pages/keenetic/install-neo.sh" | sh
exit 0
