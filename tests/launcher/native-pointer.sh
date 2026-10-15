#!/usr/bin/env bash
# Synthetic native windows only; never read or modify the real clipboard.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?A Wayland session is required}
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qsp.XXXXXXXX)
shell_pid=''
original_window=$(hyprctl activewindow -j | jq -r '.address // ""')
original_cursor=$(hyprctl cursorpos -j | jq -r '[.x,.y] | @tsv')
cleanup() {
    [[ -z $shell_pid ]] || { kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; }
    rm -rf -- "$fixture"
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
    read -r original_x original_y <<< "$original_cursor"
    hyprctl dispatch "hl.dsp.cursor.move({ x = $original_x, y = $original_y })" >/dev/null 2>&1 || true
}
trap cleanup EXIT
mkdir -p "$fixture/data" "$fixture/cache"
ln -s "$desktop_runtime/hypr" "$fixture/hypr"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$project_root/tests/launcher/native-pointer.qml" > "$fixture/shell.qml"
magick -size 64x64 pattern:checkerboard "$fixture/synthetic.png"
XDG_RUNTIME_DIR="$fixture" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" timeout 25 qs -p "$fixture" > "$fixture/log" 2>&1 & shell_pid=$!
status=0; wait "$shell_pid" || status=$?; shell_pid=''
if ((status != 0)) || ! rg -q 'PASS: native launcher pointer' "$fixture/log" \
    || rg -q 'POINTER FAIL:|FAIL!|TypeError:|ReferenceError:|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS: native launcher pointer' "$fixture/log"
