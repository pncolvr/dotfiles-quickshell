#!/usr/bin/env bash
# Synthetic rows/rules and offscreen windows; no live data, API or desktop actions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-manage-layout.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
mkdir -m700 "$fixture/r"
mkdir "$fixture/home"
printf 'exit 0\n' > "$fixture/src/services/launcher/providers/wallpaper.sh"
sed -i 's/readonly property bool animationsEnabled:/property bool animationsEnabled:/' "$fixture/src/config/Config.qml"
cat > "$fixture/src/services/audio/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool screencastActive: false }
QML
if [[ -n ${MANAGE_PREVIEWS:-} ]]; then mkdir -p "$MANAGE_PREVIEWS"; fi
sed 's@"../../src@"src@g' "$repo/tests/launcher/manage-layout.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: shared Manage' "$fixture/log" || rg -q 'MANAGE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
rg 'PASS:' "$fixture/log"
