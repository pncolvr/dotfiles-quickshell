#!/usr/bin/env bash
# Input-transparent native host with synthetic tabs; no focus or cursor movement.
set -euo pipefail
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: native panel host check requires Wayland\n'
    exit 0
fi
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-panel-host.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
mkdir -m700 "$fixture/runtime"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/panel-host.qml" > "$fixture/shell.qml"
env -u QT_QUICK_BACKEND QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 6 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: stable native panel buffer' "$fixture/log" \
    || rg -q 'HOST FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
