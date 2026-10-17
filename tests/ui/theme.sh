#!/usr/bin/env bash
# Isolated offscreen colors/controls; never changes the live theme or desktop focus.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-theme.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -Ei 's/readonly property bool darkMode: (true|false)/property bool darkMode: true/' "$fixture/src/theme/Theme.qml"
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/theme.qml" > "$fixture/shell.qml"
if [[ -n ${THEME_TEST_PREVIEWS:-} ]]; then mkdir -p -- "$THEME_TEST_PREVIEWS"; fi
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 10 qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: dark palette compatibility' "$fixture/log" || rg -q 'THEME FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
