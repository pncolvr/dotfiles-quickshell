#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-batteries-test.XXXXXX)
entry=$(mktemp "$project_root/.batteries-smoke.XXXXXX.qml")
trap 'rm -rf -- "$test_dir"; rm -f -- "$entry"' EXIT
mkdir -m 700 "$test_dir/runtime"
bash "$project_root/tests/system/logitech-batteries.sh"
mkdir "$test_dir/bin"
cat > "$test_dir/bin/solaar" <<'MOCK'
#!/usr/bin/env bash
cat <<'REPORT'
Bolt Receiver
  2: ERGO M575S Trackball
     Device path  : None
     Serial number: smoke-trackball
     Battery: 20%, BatteryStatus.DISCHARGING.
REPORT
MOCK
chmod +x "$test_dir/bin/solaar"
cat > "$entry" <<'QML'
import QtQuick
import Quickshell
Scope {
    Loader { source: "tests/system/batteries-smoke.qml" }
}
QML
output=$(PATH="$test_dir/bin:$PATH" QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$entry" 2>&1) || {
    printf '%s\n' "$output" >&2
    exit 1
}
printf '%s\n' "$output"
[[ $output == *'PASS: battery discovery'* && $output != *'BATTERIES SMOKE FAIL:'* \
    && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
    && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]

# Reopen the tooltip to repeat the timer's refresh path with slow scans and a failure.
cat > "$test_dir/bin/solaar" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
request=0
if [[ -f $BATTERY_TEST_RECEIVER_COUNTER ]]; then request=$(<"$BATTERY_TEST_RECEIVER_COUNTER"); fi
request=$((request + 1))
printf '%s\n' "$request" > "$BATTERY_TEST_RECEIVER_COUNTER"
if ((request > 1)); then sleep 0.5; fi
case $request in
    1) level=20 ;;
    2) level=50 ;;
    3) printf 'Receiver read failed\n' >&2; exit 1 ;;
    4) level=5 ;;
    *) printf 'No supported device found\n' >&2; exit 1 ;;
esac
cat <<REPORT
Bolt Receiver
  2: ERGO M575S Trackball
     Device path  : None
     Serial number: refresh-trackball
     Battery: $level%, BatteryStatus.DISCHARGING.
REPORT
MOCK
cat > "$entry" <<'QML'
import QtQuick
import Quickshell
Scope {
    Loader { source: "tests/system/batteries-refresh-smoke.qml" }
}
QML
refresh_output=$(PATH="$test_dir/bin:$PATH" BATTERY_TEST_RECEIVER_COUNTER="$test_dir/receiver-counter" \
    QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$entry" 2>&1) || {
    printf '%s\n' "$refresh_output" >&2
    exit 1
}
printf '%s\n' "$refresh_output"
[[ $refresh_output == *'PASS: receiver refresh'* && $refresh_output != *'BATTERIES REFRESH FAIL:'* \
    && $refresh_output != *'Failed to load configuration'* && $refresh_output != *'Binding loop detected'* \
    && $refresh_output != *'TypeError:'* && $refresh_output != *'ReferenceError:'* ]]

if [[ ${1:-} == --native-imports ]]; then
    cat > "$entry" <<'QML'
import QtQuick
import Quickshell
import "modules/system/batteries"
import "bar"
import "services"
Scope {
    id: root
    property int step: 0
    Component { Bar {} }
    PanelWindow {
        id: probe
        visible: false
        screen: Quickshell.screens[0]
        Batteries { id: icon; window: probe }
    }
    TooltipWindow { id: popup; screen: probe.screen }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                // Pin this test panel so real pointer movement cannot close it during the scan.
                TooltipService.togglePin(320, icon.tooltip, icon, false, probe.screen)
            } else if (root.step === 3) {
                if (BatteryService.scanningReceivers) return
                if (!popup.visible || icon.tooltipScreen !== probe.screen) {
                    console.error("BATTERIES NATIVE FAIL: tooltip or monitor")
                    Qt.quit()
                    return
                }
                console.log("LIVE BATTERIES: " + JSON.stringify(BatteryService.batteries))
                TooltipService.togglePin(320, icon.tooltip, icon, false, probe.screen)
                TooltipService.hide()
            } else if (root.step === 6) {
                if (!popup.visible) console.log("PASS: full bar imports, live batteries, tooltip opens and closes on its monitor")
                else console.error("BATTERIES NATIVE FAIL: tooltip did not close")
                Qt.quit()
            }
            root.step++
        }
    }
}
QML
    native_output=$(QT_QPA_PLATFORM=wayland timeout 55 qs -p "$entry" 2>&1) || {
        printf '%s\n' "$native_output" >&2
        exit 1
    }
    printf '%s\n' "$native_output"
    [[ $native_output == *'PASS: full bar imports'* && $native_output != *'BATTERIES NATIVE FAIL:'* \
        && $native_output != *'Failed to load configuration'* && $native_output != *'Binding loop detected'* \
        && $native_output != *'TypeError:'* && $native_output != *'ReferenceError:'* ]]
fi
