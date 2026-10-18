#!/usr/bin/env bash
# Native layer-shell handoff; isolated storage and no real clipboard access.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=${WAYLAND_DISPLAY:?A native Wayland session is required}
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qsh.XXXXXXXX)
original_window=$(hyprctl activewindow -j | jq -r '.address // ""')
cleanup() {
    if [[ $original_window =~ ^0x[0-9a-fA-F]+$ ]]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_window\" })" >/dev/null 2>&1 || true
    fi
    printf 'Native handoff logs: %s\n' "$fixture"
}
trap cleanup EXIT
# Keep the Hyprland Unix-socket path below its 108-byte limit.
mkdir -m700 "$fixture/r" "$fixture/home"
ln -s "$desktop_runtime/hypr" "$fixture/r/hypr"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
cat > "$fixture/clipboard" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$HANDOFF_TEST_DIR/actions"
[[ $1 != paste ]]
MOCK
chmod +x "$fixture/clipboard"
node - "$fixture" <<'JS'
const fs = require('node:fs'), dir = process.argv[2], file = dir + '/src/config/Config.qml';
fs.writeFileSync(file, fs.readFileSync(file, 'utf8')
    .replace(/readonly property var clipboardCommand:.*/, () => 'readonly property var clipboardCommand: ' + JSON.stringify([dir + '/clipboard']))
    .replace('clipboardMonitorEnabled: true', 'clipboardMonitorEnabled: false')
    .replace(/readonly property bool animationsEnabled:.*/, 'readonly property bool animationsEnabled: Quickshell.env("HANDOFF_ANIMATIONS") === "true"'));
JS
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
sed 's@"../../src@"src@g' "$repo/tests/launcher/clipboard-handoff-native.qml" > "$fixture/shell.qml"
for animations in true false; do
    : > "$fixture/actions"
    result=0
    env HANDOFF_TEST_DIR="$fixture" HANDOFF_ANIMATIONS="$animations" \
        QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" HOME="$fixture/home" \
        XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
        dbus-run-session -- bash "$repo/tests/runner/session.sh" \
        timeout -k 2 25 qs -p "$fixture" > "$fixture/$animations.log" 2>&1 || result=$?
    if ((result != 0)) || ! rg -q 'PASS: native Clipboard' "$fixture/$animations.log" \
        || rg -q 'HANDOFF NATIVE FAIL:|TypeError:|ReferenceError:|Failed to load configuration|Unable to connect to hyprland event socket' "$fixture/$animations.log"; then
        cat "$fixture/$animations.log"
        exit 1
    fi
    [[ $(rg -c '^restore$' "$fixture/actions") == 3 ]]
    ! rg -q '^paste$' "$fixture/actions"
    printf 'Animations %s: ' "$animations"
    rg 'PASS: native Clipboard' "$fixture/$animations.log"
done
