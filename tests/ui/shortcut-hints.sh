#!/usr/bin/env bash
# Offscreen hint layout; no native desktop focus or real user data.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-hints.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed 's@"../../src@"src@g' "$repo/tests/ui/shortcut-hints.qml" > "$fixture/shell.qml"
for catalog in "$repo"/src/i18n/languages/*.json; do
    jq '[
        (to_entries[] | select(.key | contains(".shortcuts.")) | .value
            | if type == "object" then .[] else . end
            | gsub("%n"; "2") | gsub("%1"; "Ctrl+Shift+R") | gsub("%2"; "Open")
            | gsub("%3"; "Shift+Space") | gsub("%4"; "Ctrl+A") | gsub("%5"; "Ctrl+Shift+A")),
        .["files.shortcuts.selection"],
        (.["vault.shortcuts.details"] + " · Ctrl+E: " + .["common.actions.edit"])
    ]' "$catalog"
done | jq -s 'add' > "$fixture/samples.json"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 25 qs -p "$fixture" > "$fixture/log" 2>&1 || { tail -100 "$fixture/log"; exit 1; }
if ! rg -q 'PASS: multilingual shortcut' "$fixture/log" || rg -q 'HINTS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    tail -100 "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
