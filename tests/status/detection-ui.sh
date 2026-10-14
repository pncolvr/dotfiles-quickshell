#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-detection-ui.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
ln -s "$root_dir/src" "$fixture/src"
sed 's@"../../src@"src@g' "$root_dir/tests/status/detection-ui.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" timeout 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
cat "$fixture/log"
rg -q 'PASS: detection keyboard/mouse' "$fixture/log"
! rg -q 'DETECTION FAIL:|FAIL!|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"
