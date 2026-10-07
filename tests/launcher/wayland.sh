#!/usr/bin/env bash
# Briefly opens only the isolated picker, then closes it and restores the original focus.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-picker-wayland.XXXXXXXX)
original=$(hyprctl activewindow -j | jq -r '.address // ""')
cleanup() {
    if [[ $original =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original\" })" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
cp -a "$project_root/src" "$test_dir/src"
mkdir "$test_dir/data"
# This test must never read or capture the real clipboard.
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
sed 's@"../../src@"src@g' "$project_root/tests/launcher/wayland-smoke.qml" > "$test_dir/shell.qml"
export PICKER_TEST_SCREENSHOT=${PICKER_TEST_SCREENSHOT:-/tmp/quickshell-picker-preview.png}
output=$(QT_QPA_PLATFORM=wayland timeout 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: native picker'* && $output != *'PICKER FAIL:'* && $output != *'Failed to load configuration'* \
    && $output != *'Binding loop detected'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
