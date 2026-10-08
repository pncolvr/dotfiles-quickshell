#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-batched-model.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir "$test_dir/ui"
cp "$project_root/src/theme/ui/components/BatchedListModel.qml" "$test_dir/ui/"
printf 'BatchedListModel 1.0 BatchedListModel.qml\n' > "$test_dir/ui/qmldir"
sed 's@"../../src/theme/ui"@"ui"@' "$project_root/tests/qml/batched-model-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" timeout 10 qs -p "$test_dir" 2>&1) \
    || { printf '%s\n' "$output" >&2; exit 1; }
[[ $output == *'PASS:'* && $output != *'BATCH FAIL:'* && $output != *'TypeError:'* \
    && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]] \
    || { printf '%s\n' "$output" >&2; exit 1; }
while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
