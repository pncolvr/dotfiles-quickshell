#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-project-manage.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
ln -s "$repo_dir/src" "$fixture/src"
sed 's@"../../src@"src@g' "$repo_dir/tests/projects/manage.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg 'PASS:|MANAGE FAIL:' "$fixture/log"
if ! rg -q 'PASS: project management' "$fixture/log" || rg -q 'MANAGE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA integrity_check;') == ok ]]
