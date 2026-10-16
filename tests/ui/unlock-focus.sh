#!/usr/bin/env bash
# Brief native focus check with synthetic fields; never moves the cursor or opens a vault.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?}
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qsuf.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
ln -s "$desktop_runtime/hypr" "$fixture/runtime/hypr"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/unlock-focus.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 6 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native unlock' "$fixture/log" \
    || rg -q 'UNLOCK FOCUS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
