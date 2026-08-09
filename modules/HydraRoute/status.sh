#!/bin/sh
# status.sh — статус демона HydraRoute Neo.
# Код возврата 'neo status' используется как есть (0 = служба активна).
neo status >/dev/null 2>&1
exit $?
