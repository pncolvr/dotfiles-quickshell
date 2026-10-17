#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-capture-sync.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
fixture_dir="$test_dir/src/services"
mkdir -p "$fixture_dir/hyprland" "$test_dir/src/config"
mkdir -m 700 "$test_dir/runtime"
# Production coordinator; no database service exists in this fixture.
sed '\|^import Quickshell.Hyprland$|d' \
    "$project_root/src/services/hyprland/HyprlandEventsService.qml" > "$fixture_dir/hyprland/HyprlandEventsService.qml"
cat > "$fixture_dir/AudioService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject {
    readonly property var compositor: Hyprland
    property int captureCount: 0
    readonly property bool screencastActive: captureCount > 0
    property bool screencastReady: false
}
QML
cat > "$fixture_dir/Hyprland.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { signal rawEvent(var event) }
QML
printf 'singleton Config 1.0 Config.qml\n' > "$test_dir/src/config/qmldir"
cat > "$fixture_dir/WindowService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { function buildWindows() {} }
QML
cat > "$fixture_dir/StatusService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { function reload() {} }
QML
for type in AudioService Hyprland WindowService StatusService; do
    printf 'singleton %s 1.0 %s.qml\n' "$type" "$type" >> "$fixture_dir/qmldir"
done
printf 'singleton HyprlandEventsService 1.0 hyprland/HyprlandEventsService.qml\n' >> "$fixture_dir/qmldir"
cat > "$test_dir/record" <<'SH'
#!/bin/sh
printf '%s %s\n' "$1" "$2" >> "$CAPTURE_SYNC_LOG"
sleep 0.12
SH
chmod 700 "$test_dir/record"
export CAPTURE_SYNC_LOG="$test_dir/calls" CAPTURE_SYNC_COMMAND="$test_dir/record"
export QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
sed 's@"../../src@"src@g' "$project_root/tests/hyprland/capture-sync.qml" > "$test_dir/shell.qml"
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
for phase in on off restart-on sharing; do
    export CAPTURE_SYNC_PHASE="$phase"
    case $phase in off) enabled=false ;; *) enabled=true ;; esac
    # Rewrite the actual fixture Config.qml before each process starts.
    cat > "$test_dir/src/config/Config.qml" <<QML
pragma Singleton
import QtQml
import Quickshell
QtObject {
    property bool hyprlandAnimationsEnabled: $enabled
    readonly property bool hyprlandHideApplicationsEnabled: true
    readonly property var hyprlandSynchronizeCaptureCommand: (active, enabled) =>
        [Quickshell.env("CAPTURE_SYNC_COMMAND"), String(active), String(enabled)]
}
QML
    : > "$CAPTURE_SYNC_LOG"
    output=$(timeout 12 dbus-run-session --config-file "$test_dir/bus.conf" -- qs -p "$test_dir/shell.qml" 2>&1) || {
        printf '%s\n' "$output" >&2; exit 1;
    }
    if [[ $output != *"PASS: capture synchronization $phase"* ]] \
        || rg -q 'CAPTURE SYNC FAIL|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|WARN scene|ERROR' <<< "$output"; then
        printf '%s\n' "$output" >&2; exit 1
    fi
    printf 'PASS: capture synchronization %s; Config.qml honored\n' "$phase"
done
