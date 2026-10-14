#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-notification-animation.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache" "$test_dir/bin"
cat > "$test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == clients ]]; then printf '[]\n'; else printf 'false\n'; fi
MOCK
chmod +x "$test_dir/bin/hyprctl"
test_platform=offscreen
unset HYPRLAND_INSTANCE_SIGNATURE
if [[ ${1:-} == --wayland ]]; then
    test_platform=wayland
    if [[ ${WAYLAND_DISPLAY:-} != /* ]]; then export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"; fi
    cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
import "file://$project_root/src/modules/system/notifications"
Scope { NotificationPopupWindow {
    id: host
    animationsEnabled: fixture.item?.motionEnabled ?? true
    popupStack.entries: fixture.item?.entries ?? []
    Loader {
        id: fixture
        source: "file://$project_root/tests/notifications/animation-smoke.qml"
        onLoaded: { item.stack = host.popupStack; item.nativeHost = host }
    }
} }
QML
else
    unset WAYLAND_DISPLAY
    cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
import "file://$project_root/src/modules/system/notifications"
Scope { FloatingWindow {
    visible: true
    implicitWidth: 600
    implicitHeight: 800
    NotificationPopupStack {
        id: stack
        x: 32; y: 24; width: 480
        entries: fixture.item?.entries ?? []
        animationsEnabled: fixture.item?.motionEnabled ?? true
    }
    Loader {
        id: fixture
        source: "file://$project_root/tests/notifications/animation-smoke.qml"
        onLoaded: item.stack = stack
    }
} }
QML
fi
cat > "$test_dir/bus.conf" <<'BUS'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
BUS
output=$(QT_QPA_PLATFORM="$test_platform" QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
    PATH="$test_dir/bin:$PATH" PIPEWIRE_REMOTE=notification-animation-test \
    dbus-run-session --config-file "$test_dir/bus.conf" -- timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
if [[ $output != *'PASS: notification slides'* ]] || rg -q 'ANIMATION FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration|WARN scene' <<< "$output"; then
    printf '%s\n' "$output" >&2; exit 1
fi
printf 'PASS: notification entrance/exit, inertia, replacements, gap closure, interrupted motion, sharing policy and idle rendering (%s)\n' "$test_platform"
