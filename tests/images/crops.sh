#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-image-crops.XXXXXXXX)
previous_window=""
cleanup() {
    if [[ -n ${CROP_TEST_SCREENSHOT:-} && -f $test_dir/rendered.png ]]; then cp -- "$test_dir/rendered.png" "$CROP_TEST_SCREENSHOT"; fi
    if [[ -n $previous_window ]]; then hyprctl dispatch focuswindow "address:$previous_window" >/dev/null 2>&1 || true; fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
cat > "$test_dir/ring.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="2048"><rect width="2048" height="2048" fill="#8020c0"/><circle cx="1024" cy="1024" r="924" fill="#dd5060" stroke="#00ff00" stroke-width="56"/><rect x="900" y="840" width="248" height="160" fill="black"/></svg>
SVG
magick "$test_dir/ring.svg" "$test_dir/ring.png"
cat > "$test_dir/plain.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1024"><rect width="2048" height="1024" fill="#ab3465"/></svg>
SVG
cat > "$test_dir/black.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><rect width="512" height="512" fill="black"/><rect x="80" y="80" width="352" height="352" fill="#cc3456"/><rect x="220" y="220" width="72" height="72" fill="black"/></svg>
SVG
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 20 /usr/lib/qt6/bin/qmltestrunner \
    -input "$project_root/tests/images/tst-ring.qml" > "$test_dir/detector.log" 2>&1 \
    || { cat "$test_dir/detector.log" >&2; exit 1; }
test_platform=offscreen
if [[ ${1:-} == --wayland ]]; then
    test_platform=wayland
    if command -v hyprctl >/dev/null && command -v jq >/dev/null; then
        previous_window=$(hyprctl -j activewindow 2>/dev/null | jq -r '.address // empty') || previous_window=""
    fi
    if [[ ${WAYLAND_DISPLAY:-} != /* ]]; then export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; fi
fi
cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source:"file://$project_root/tests/images/crop-ui.qml" } }
QML
CROP_TEST_DIR="$test_dir" QT_QPA_PLATFORM="$test_platform" QT_NO_XDG_DESKTOP_PORTAL=1 PIPEWIRE_REMOTE=image-crops-test \
    XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
    timeout 15 qs -p "$test_dir/shell.qml" > "$test_dir/ui.log" 2>&1 \
    || { cat "$test_dir/ui.log" >&2; exit 1; }
if ! rg -q 'PASS: cached shared crops' "$test_dir/ui.log" \
    || rg -q 'IMAGE CROP FAIL:|TypeError:|ReferenceError:|Binding loop|WARN scene|Failed to load configuration' "$test_dir/ui.log"; then
    cat "$test_dir/ui.log" >&2; exit 1
fi
if [[ $test_platform == wayland ]]; then
    sed "s|@CROP_RENDERED@|file://$test_dir/rendered.png|" "$project_root/tests/images/render-check.qml" > "$test_dir/render-check.qml"
    QT_QPA_PLATFORM=offscreen timeout 15 /usr/lib/qt6/bin/qmltestrunner -input "$test_dir/render-check.qml" \
        > "$test_dir/pixels.log" 2>&1 \
        || { cat "$test_dir/ui.log" "$test_dir/pixels.log" >&2; exit 1; }
    printf 'PASS: native GPU ring removal, portrait detail, antialiased circular alpha and small-avatar mipmap fringe checks\n'
fi
rg 'PASS:|IMAGE CROP.*TIMING:' "$test_dir/ui.log"
printf 'PASS: colored ring geometry and conservative fallback (%s)\n' "$test_platform"
