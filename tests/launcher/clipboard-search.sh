#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-clipboard-search.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed 's@"../../src@"src@g' "$project_root/tests/launcher/clipboard-search-smoke.qml" > "$test_dir/shell.qml"
# Search cases control their own settings, independently of the live Config.
sed -E -i 's/readonly property bool pickerFuzzySearch: (true|false)/property bool pickerFuzzySearch: true/;s/readonly property bool pickerSmartCase: (true|false)/readonly property bool pickerSmartCase: true/' "$test_dir/src/config/Config.qml"
output=$(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" \
    XDG_CACHE_HOME="$test_dir/cache" timeout 30 qs -p "$test_dir/shell.qml" 2>&1) || {
    printf '%s\n' "$output" >&2; exit 1
}
printf '%s\n' "$output"
[[ $output == *'PASS: cached clipboard search'* && $output != *'SEARCH FAIL:'* \
    && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop'* ]]
