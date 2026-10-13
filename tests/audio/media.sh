#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-media.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
cat > "$test_dir/art.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#729fcf"/></svg>
SVG
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/audio/media-smoke.qml" } }
QML
output=$(MEDIA_TEST_ART="$test_dir/art.svg" QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: media controls'* && $output != *'MEDIA FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop'* ]]
