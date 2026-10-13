#!/usr/bin/env bash
set -euo pipefail
umask 077
mode=$(<"$RBW_TEST_ROOT/control")
permissions=600 fork=''
[[ $mode != permissions ]] || permissions=666
[[ $mode != peer ]] || fork=,fork
(
    for ((attempt=0;attempt<200;attempt++)); do
        if [[ -S $QUTERBW_DIRECTORY/reply ]]; then
            printf 'rbw-fill-once %s\n' "$QUTERBW_HANDLE" > "$QUTE_FIFO"
            exit 0
        fi
        sleep 0.01
    done
) &
wire() {
    case $mode in
        oversized) printf '\000\017\102\100' ;;
        malformed) printf '\000\000\000\010not-json' ;;
        injected) printf '\000\000\000\033{"password":"ERROR_MARKER"}' ;;
        *) printf '\000\000\000\002{}' ;;
    esac
    sleep 2
}
exec socat "UNIX-LISTEN:$QUTERBW_DIRECTORY/reply,mode=$permissions$fork" STDIO < <(wire) > /dev/null
