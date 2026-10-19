#!/usr/bin/env bash
# Isolated catalogs/UI only. Never takes native focus or uses real user data.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
node "$repo_dir/tests/i18n/catalog.mjs"
fixture=$(mktemp -d /tmp/qs-i18n.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
# A third catalog must be discovered without editing any production QML/JS.
printf '%s\n' '{"$locale":"en_GB","common.actions.save":"Synthetic save"}' > "$fixture/src/i18n/languages/zz.json"
sed -Ei 's/readonly property string language: "[^"]+"/property string language: "en"/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/i18n/runtime.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 1 10 qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: QML catalogs' "$fixture/log" || rg -q 'I18N FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
rg 'PASS:' "$fixture/log"
# Verify the real readonly Config override after an explicit bar-style reload.
# The binding-only fixture above deliberately makes it mutable; restore production semantics.
sed -i 's/^    property string language:/    readonly property string language:/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/i18n/reload.qml" > "$fixture/reload.qml"
probe_pid=''
cleanup() {
    if [[ -n $probe_pid ]]; then kill "$probe_pid" 2>/dev/null || true; wait "$probe_pid" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1
export XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
unset WAYLAND_DISPLAY
qs -p "$fixture/reload.qml" > "$fixture/reload.log" 2>&1 & probe_pid=$!
wait_label() {
    for ((attempt=0;attempt<100;attempt++)); do
        if [[ $(qs ipc -p "$fixture/reload.qml" call i18ncheck label 2>/dev/null || true) == "$1" ]]; then return; fi
        sleep 0.05
    done
    cat "$fixture/reload.log"; return 1
}
wait_label Save
sed -i 's/property string language: "en"/property string language: "pt"/' "$fixture/src/config/Config.qml"
qs ipc -p "$fixture/reload.qml" call i18ncheck reload
wait_label Guardar
if rg -q 'TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/reload.log"; then cat "$fixture/reload.log"; exit 1; fi
printf 'PASS: explicit bar-style reload applies Config.language from disk\n'
