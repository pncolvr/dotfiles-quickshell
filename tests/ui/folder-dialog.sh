#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-folder-dialog.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/folder % café"
ln -s "$repo_dir/src" "$fixture/src"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/folder-dialog.qml" > "$fixture/shell.qml"
folder_url=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).as_uri())' "$fixture/folder % café")
env -u WAYLAND_DISPLAY FOLDER_TEST_PATH="$fixture/folder % café" FOLDER_TEST_URL="$folder_url" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 10 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: folder result' "$fixture/log" \
    || rg -q 'FOLDER DIALOG FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
