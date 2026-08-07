#!/bin/sh
# diagnostics.sh — базовая диагностика окружения роутера.

kt_diag_check() {
    # kt_diag_check "Название" <команда...>
    label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf "%b\342\234\224%b %s\n" "$C_GREEN" "$C_RESET" "$label"
        return 0
    else
        printf "%b\342\234\230%b %s\n" "$C_RED" "$C_RESET" "$label"
        return 1
    fi
}

kt_diag_internet() {
    kt_has_cmd curl && curl -s --max-time 3 -o /dev/null https://1.1.1.1 && return 0
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
}

kt_diag_dns() {
    kt_has_cmd curl && curl -s --max-time 3 -o /dev/null https://ya.ru && return 0
    ping -c 1 -W 2 ya.ru >/dev/null 2>&1
}

kt_diag_entware() {
    [ -x /opt/bin/opkg ] || kt_has_cmd opkg
}

kt_diag_usb() {
    # Наличие точки монтирования /opt как признак работающего USB-накопителя Entware
    mount 2>/dev/null | grep -q " /opt "
}

kt_diag_wireguard() {
    lsmod 2>/dev/null | grep -qi wireguard || [ -d /sys/module/wireguard ]
}

kt_diag_permissions() {
    [ -w "$KT_HOME" ]
}

kt_diagnostics_run() {
    kt_header "Диагностика"
    ok=0; total=0

    total=$((total+1)); kt_diag_check "Интернет"        kt_diag_internet    && ok=$((ok+1))
    total=$((total+1)); kt_diag_check "DNS"              kt_diag_dns         && ok=$((ok+1))
    total=$((total+1)); kt_diag_check "Entware"          kt_diag_entware     && ok=$((ok+1))
    total=$((total+1)); kt_diag_check "USB (/opt)"       kt_diag_usb         && ok=$((ok+1))
    total=$((total+1)); kt_diag_check "WireGuard"        kt_diag_wireguard   && ok=$((ok+1))
    total=$((total+1)); kt_diag_check "Права доступа"    kt_diag_permissions && ok=$((ok+1))

    kt_line
    echo "Пройдено: $ok из $total проверок"
}
