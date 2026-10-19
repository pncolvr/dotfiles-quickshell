#!/usr/bin/env bash
# Synthetic artwork only; offscreen, no live audio, input or desktop access.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
platform=(env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software)
if [[ ${1:-} == --gpu ]]; then
    display=${WAYLAND_DISPLAY:?Wayland display required for GPU artwork checks}
    [[ $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
    platform=(env -u QT_QUICK_BACKEND QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" MEDIA_ARTWORK_GPU=1)
fi
fixture=$(mktemp -d /tmp/quickshell-media-artwork.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed 's@"../../src@"src@g' "$repo/tests/audio/media-artwork.qml" > "$fixture/shell.qml"
if [[ ${1:-} == --gpu ]]; then
    # A passive layer surface: captures its own viewport, never the desktop.
    sed -i '/^import Quickshell$/a import Quickshell.Wayland' "$fixture/shell.qml"
    sed -i 's/^    FloatingWindow {/    PanelWindow {\n        anchors.top: true\n        exclusiveZone: 0\n        color: "transparent"\n        mask: Region { width: 0; height: 0 }\n        WlrLayershell.namespace: "quickshell-artwork-check"\n        WlrLayershell.layer: WlrLayer.Overlay\n        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None/' "$fixture/shell.qml"
fi
cat > "$fixture/art.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"><rect width="640" height="480" fill="#23698d"/><path d="M0 480L320 0L640 480Z" fill="#e69a46"/><circle cx="320" cy="280" r="80" fill="#183047"/></svg>
SVG
"${platform[@]}" QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
cat "$fixture/log"
! rg -q 'ARTWORK FAIL:|FAIL!|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"
rg -q 'PASS: fullscreen artwork' "$fixture/log"
