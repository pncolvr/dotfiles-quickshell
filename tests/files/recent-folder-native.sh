#!/usr/bin/env bash
# Synthetic native dialog and private preferences; never moves the real pointer.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-recent-native.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
display=${WAYLAND_DISPLAY:?}
[[ $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/chosen directory"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/; s@Qt.resolvedUrl("../services/files/folder-files.sh")@Qt.resolvedUrl("../../slow-folder.sh")@' "$fixture/src/config/Config.qml"
cat > "$fixture/slow-folder.sh" <<'SLOW'
sleep 0.8
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/src/services/files/folder-files.sh" "$@"
SLOW
sed 's@"../../src@"src@g' "$repo_dir/tests/files/recent-folder-native.qml" > "$fixture/shell.qml"
RECENT_NATIVE_FOLDER="$fixture/chosen directory" QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native Recent Files' "$fixture/log" \
    || rg -q 'RECENT NATIVE FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
