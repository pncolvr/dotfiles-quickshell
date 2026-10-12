#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: pulse shader check requires a native Wayland GPU surface\n'
    exit 0
fi
test_dir=$(mktemp -d /tmp/quickshell-pulse.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/qml/pulse-smoke.qml" } }
QML
output=$(QT_QPA_PLATFORM=wayland timeout -k 2 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: GPU pulse'* && $output == *'PASS: disabling pulse'* \
    && $output == *'PASS: hidden text'* && $output == *'PASS: hidden window'* \
    && $output == *'PASS: showing the window'* \
    && $output == *'PASS: staggered pulses'* && $output == *'PASS: resumed pulse rejoins'* \
    && $output != *'PULSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
    && $output != *'Failed to load configuration'* && $output != *'Failed to load shader'* ]]
