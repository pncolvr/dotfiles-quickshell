#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$QUTE_FIFO" > "$RBW_TEST_ROOT/browser-fifo"
printf '%s' "$$" > "$RBW_TEST_ROOT/driver-pid"
mkfifo "$RBW_TEST_ROOT/keepalive"
exec {keepalive}<>"$RBW_TEST_ROOT/keepalive"
IFS= read -r -t 120 unused <&"$keepalive" || true
