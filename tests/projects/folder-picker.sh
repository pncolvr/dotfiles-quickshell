#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
display=${WAYLAND_DISPLAY:?A Wayland compositor is required}
[[ $display == /* ]] || display="${XDG_RUNTIME_DIR:?}/$display"
test_dir=$(mktemp -d /tmp/quickshell-project-dialog.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/config/data" "$test_dir/home" "$test_dir/single folder"
mkdir -m700 "$test_dir/runtime"
# Isolate services from the desktop clipboard, real database and private configs.
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir/config" -xf -
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/config/src/config/Config.qml"
sed 's@"../../src@"src@g' "$project_root/tests/projects/folder-picker-smoke.qml" > "$test_dir/config/shell.qml"
export PROJECT_TEST_DIR="$test_dir" HOME="$test_dir/home" QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
timeout 15 qs -p "$test_dir/config/shell.qml" > "$test_dir/log" 2>&1 || { cat "$test_dir/log"; exit 1; }
cat "$test_dir/log"
rg -q 'PASS: project folder picker returns focus' "$test_dir/log"
! rg -q 'PROJECT FAIL:|TypeError:|ReferenceError:|Binding loop detected|Failed to load configuration' "$test_dir/log"
