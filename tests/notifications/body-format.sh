#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-body-format.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/data" "$test_dir/cache"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
sed 's@"../../src@"src@g' "$project_root/tests/notifications/body-format-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
    XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" timeout 10 qs -p "$test_dir" 2>&1) \
    || { printf '%s\n' "$output" >&2; exit 1; }
[[ $output == *'PASS:'* && $output != *'BODY FORMAT FAIL:'* && $output != *'TypeError:'* \
    && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] \
    || { printf '%s\n' "$output" >&2; exit 1; }
while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
