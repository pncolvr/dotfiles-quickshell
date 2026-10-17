#!/usr/bin/env bash
# Exercise panel lifecycle offscreen without moving desktop focus or the cursor.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-panel-lifecycle.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
ln -s "$project_root/src" "$fixture/src"
sed 's@"../../src@"src@g' "$project_root/tests/ui/tooltip-search-smoke.qml" > "$fixture/shell.qml"
output=$(env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_CACHE_HOME="$fixture/cache" XDG_DATA_HOME="$fixture/data" \
    timeout 15 qs -p "$fixture/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
if [[ $output != *'PASS: scoped panel'* ]] \
    || rg -q 'LIFECYCLE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' <<< "$output"; then
    printf '%s\n' "$output" >&2
    exit 1
fi
awk '/PASS:/ { print; exit }' <<< "$output"
