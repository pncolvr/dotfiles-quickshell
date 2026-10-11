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
