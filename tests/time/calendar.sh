#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-calendar-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
cp -r "$project_root/src" "$test_dir/src"
# Drive the existing clock binding across civil date boundaries without changing the system clock.
cat > "$test_dir/src/services/time/TimeService.qml" <<'QML'
pragma Singleton
import Quickshell
Singleton {
    property string time: new Date(2026, 9, 23, 12).toString()
    property bool showSeconds: false
}
QML
sed 's@"../../src@"src@g' "$project_root/tests/time/calendar-smoke.qml" > "$test_dir/shell.qml"
output=$(TZ=Europe/Lisbon QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
    timeout -k 2 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: calendar transitions'* && $output != *'CALENDAR FAIL:'* \
    && $output != *'Binding loop detected'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
