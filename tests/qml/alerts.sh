#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-alerts.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
mkdir "$test_dir/service"
cp "$project_root/src/services/ui/AlertService.qml" "$test_dir/service/AlertService.qml"
printf 'singleton AlertService 1.0 AlertService.qml\n' > "$test_dir/service/qmldir"
cat > "$test_dir/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "service"
Scope {
    id: root
    property bool failed: false
    property int step: 0
    function check(ok, message) { if (!ok) { failed = true; console.error("ALERT FAIL:", message) } }
    Component.onCompleted: {
        check(AlertService.post("network", "no internet access"), "persistent network alert")
        check(!AlertService.post("", "empty", "info", 0), "reject empty ID")
        check(!AlertService.post("bad", "text", "unknown", 0), "reject unknown severity")
        check(!AlertService.post("bad", "text", "info", -1), "reject negative duration")
        check(AlertService.messages[0].captureBlocking === false, "ordinary alerts do not block capture")
        AlertService.post("capture", "starting", "success", 0, true)
        check(AlertService.messages[1].captureBlocking === true, "capture notice is explicitly marked")
        AlertService.post("capture", "finished", "info", 0)
        check(AlertService.messages[1].captureBlocking === false, "ordinary replacement releases capture blocking")
        AlertService.dismiss("capture")
        AlertService.post("recording", "starting", "success", 40)
        AlertService.post("recording", "stopped", "info", 400)
        check(AlertService.messages.length === 2 && AlertService.messages[1].text === "stopped",
            "same ID replaces its message")
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            root.step++
            if (root.step === 1) {
                root.check(AlertService.messages.length === 2, "replacement resets expiry")
                AlertService.post("temporary", "warning", "warning", 30)
            } else if (root.step === 2) {
                root.check(AlertService.messages.length === 2, "earlier alert expires independently")
                AlertService.dismiss("recording")
                root.check(AlertService.messages.length === 1, "explicit dismissal")
            } else {
                root.check(AlertService.messages.length === 1 && AlertService.messages[0].expiresAt === 0,
                    "persistent messages survive expiration")
                AlertService.dismiss("network")
                root.check(AlertService.messages.length === 0, "last dismissal empties panel")
                if (!root.failed) console.log("PASS: alert replacement, validation, dismissal and expiration")
                Qt.quit()
            }
        }
    }
}
QML
output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" \
    timeout -k 2 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: alert replacement'* && $output != *'ALERT FAIL:'* \
    && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Failed to load configuration'* ]]

if [[ ${1:-} == --native ]]; then
    native_wayland_display=${WAYLAND_DISPLAY:-wayland-0}
    [[ $native_wayland_display == /* ]] || native_wayland_display=${XDG_RUNTIME_DIR:?}/$native_wayland_display
    tar -C "$project_root" --exclude='*.env' --exclude='*.json' -cf - src | tar -C "$test_dir" -xf -
    cat > "$test_dir/shell.qml" <<'QML'
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "src/bar"
import "src/services"
Scope {
    id: root
    property int step: 0
    property bool failed: false
    property bool captured: false
    function check(ok, message) { if (!ok) { failed = true; console.error("ALERT FAIL:",message) } }
    AlertWindow { id: alert; screen: Quickshell.screens[0] }
    Component.onCompleted: AlertService.post("backup", "Backup display test: preparing", "info")
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            root.step++
            if (root.step === 1) {
                root.check(alert.visible && alert.contentWidth > 0 && alert.contentHeight > 0,"progress surface is visible")
                root.check(alert.screen === Quickshell.screens[0] && alert.WlrLayershell.layer === WlrLayer.Overlay
                    && alert.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,"correct monitor/layer without taking focus")
                AlertService.post("backup","Backup display test: encrypting archive","info")
            } else if (root.step === 2) {
                root.check(AlertService.messages.length === 1,"progress replaces its previous stage")
                AlertService.post("backup","Backup display test: created /tmp/fixture/example.7z","success",15000)
            } else if (root.step === 3) {
                root.check(alert.contentX >= 0 && alert.contentX + alert.contentWidth <= alert.width,"message fits the monitor")
                const path = Quickshell.env("ALERT_TEST_SCREENSHOT")
                if (path) alert.surfaceComponent.grabToImage(result => { result.saveToFile(path); root.captured = true })
                else root.captured = true
            } else if (root.step >= 4 && root.captured) {
                AlertService.dismiss("backup")
                root.check(!alert.visible,"dismissal hides the surface")
                if (!root.failed) console.log("PASS: native alert surface, monitor, overlay, focus, progress replacement and completion")
                stop(); Qt.quit()
            } else if (root.step > 20) {
                root.check(false,"screenshot timed out"); stop(); Qt.quit()
            }
        }
    }
}
QML
    output=$(QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$native_wayland_display" QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" \
        XDG_DATA_HOME="$test_dir/local" XDG_CACHE_HOME="$test_dir/cache" \
        timeout -k 2 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *'PASS: native alert surface'* && $output != *'ALERT FAIL:'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Failed to load configuration'* ]]
fi
