#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-bar-visibility.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/bar-visibility.qml" > "$fixture/shell.qml"
mkdir -p "$fixture/src/ui"
cp -R "$repo_dir/src/ui/bar" "$fixture/src/ui/"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" timeout 3 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg -q 'PASS: bar auto-hide state' "$fixture/log" || { cat "$fixture/log"; exit 1; }
rg 'PASS:' "$fixture/log"
