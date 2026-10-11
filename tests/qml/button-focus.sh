#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-button-focus.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir "$test_dir/data"
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/qml/button-focus-smoke.qml" } }
QML
output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: pointer clicks'* && $output != *'BUTTON FOCUS FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Failed to load configuration'* ]]
