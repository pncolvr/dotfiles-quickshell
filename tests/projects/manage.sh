#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-project-manage.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/home"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
printf 'exit 0\n' > "$fixture/src/services/launcher/providers/wallpaper.sh"
# Search cases control their own settings, independently of the live Config.
sed -E -i 's/readonly property bool pickerFuzzySearch: (true|false)/property bool pickerFuzzySearch: true/;s/readonly property bool pickerSmartCase: (true|false)/readonly property bool pickerSmartCase: true/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/projects/manage.qml" > "$fixture/shell.qml"
HOME="$fixture/home" QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg 'PASS:|MANAGE FAIL:' "$fixture/log"
if ! rg -q 'PASS: project management' "$fixture/log" || rg -q 'MANAGE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA integrity_check;') == ok ]]
