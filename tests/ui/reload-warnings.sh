#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-reload-warnings.XXXXXXXX)
cleanup() {
    local result=$?
    if ((result != 0)); then cat "$fixture/log" >&2; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/twitchEnabled: true/twitchEnabled: false/;s/batteriesEnabled: true/batteriesEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
# Exercise the production root's actual teardown callback, while keeping native
# panels and the live desktop out of this isolated engine-generation test.
handler=$(rg -m1 '^  Component\.onDestruction: .+$' "$project_root/shell.qml") \
    || { printf 'Missing shell generation cleanup\n' >&2; exit 1; }
ROOT_DESTRUCTION_HANDLER="${handler#  }" awk '
    { gsub(/"\.\.\/\.\.\/src/, "\"src") }
    /\/\/ ROOT_DESTRUCTION_HANDLER/ {
        marker = index($0, "// ROOT_DESTRUCTION_HANDLER")
        $0 = substr($0, 1, marker - 1) ENVIRON["ROOT_DESTRUCTION_HANDLER"] substr($0, marker + length("// ROOT_DESTRUCTION_HANDLER"))
    }
    { print }
' "$project_root/tests/ui/reload-warnings.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    QS_DISABLE_CRASH_HANDLER=1 MALLOC_CONF="${MALLOC_CONF:+$MALLOC_CONF,}junk:true" timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1
rg -q 'PASS: twenty tooltip generations' "$fixture/log"
! rg -q 'RELOAD WARNINGS FAIL|Unable to assign|Failed to load configuration|TypeError:|ReferenceError:|Binding loop' "$fixture/log"
printf 'PASS: tooltip references and background workers released before old-generation teardown across twenty reloads\n'

# Use an independent entry point without the real shell's cleanup callback.
sed 's@"../../src@"src@g' "$project_root/tests/ui/worker-lifetime.qml" > "$fixture/worker.qml"
for mode in soft hard; do
    for entry in direct loader; do
        printf 0 > "$fixture/worker-generations"
        if [[ $entry == direct ]]; then cp "$fixture/worker.qml" "$fixture/shell.qml"
        else
            cat > "$fixture/shell.qml" <<'QML'
import QtQuick
import Quickshell
Scope { Loader { source: "worker.qml" } }
QML
        fi
        env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
            XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
            QS_DISABLE_CRASH_HANDLER=1 WORKER_RELOAD_MODE="$mode" \
            MALLOC_CONF="${MALLOC_CONF:+$MALLOC_CONF,}junk:true" \
            timeout -k 2 12 qs -p "$fixture" > "$fixture/log" 2>&1
        rg -q 'PASS: ten worker generations reload and exit without a shell cleanup callback' "$fixture/log"
        ! rg -q 'TypeError:|ReferenceError:|Binding loop|WARN scene|Failed to load configuration' "$fixture/log"
        printf 'PASS: worker lifetime survives ten %s reloads and clean exit (%s entry)\n' "$mode" "$entry"
    done
done
