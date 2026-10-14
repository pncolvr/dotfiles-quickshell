#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-project-grouping.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
ln -s "$root_dir/src" "$fixture/src"
sed 's@"../../src@"src@g' "$root_dir/tests/projects/grouping.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg 'PASS:|GROUPING FAIL:' "$fixture/log"
if ! rg -q 'PASS: project grouping' "$fixture/log" || rg -q 'GROUPING FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA integrity_check;') == ok ]]
