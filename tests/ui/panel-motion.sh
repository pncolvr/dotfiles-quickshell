#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-panel-motion.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i -E 's/readonly property bool adaptiveBarEnabled: (true|false)/readonly property bool adaptiveBarEnabled: false/' "$fixture/src/config/Config.qml"
sed -i 's/readonly property bool screencastActive:.*/property bool screencastActive: false/' "$fixture/src/services/audio/AudioService.qml"
# Only the isolated Config is writable for runtime policy checks.
sed -i 's/readonly property bool animationsEnabled:.*/property bool animationsEnabled: true/;s/readonly property bool animateDuringScreenShare:.*/property bool animateDuringScreenShare: false/' "$fixture/src/config/Config.qml"
sed -i -E 's/readonly property bool (screenSharePulseEnabled|notificationBorderAnimationEnabled|micPulseEnabled|volumePulseEnabled|mediaVisualizerEnabled):.*/property bool \1: true/' "$fixture/src/config/Config.qml"
# No desktop notification registration or real notification data in this fixture.
cat > "$fixture/src/services/notifications/NotificationService.qml" <<'MOCK'
pragma Singleton
import Quickshell
Singleton {
    property var liveEntries: ({})
    function liveFor(entry) { return entry }
    function actions(_entry, _history) { return [] }
    function setPopupHovered(_entry, _hovered) {}
    function dismiss(_entry, _history) {}
    function activate(_entry) {}
    function invoke(_entry, _action) {}
}
MOCK
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/panel-motion.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: shared dropdown' "$fixture/log" \
    || rg -q 'MOTION FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|FAIL!' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
