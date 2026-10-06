#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-audio-test.XXXXXX)
entry=$(mktemp "$project_root/.audio-smoke.XXXXXX.qml")
trap 'rm -rf -- "$test_dir"; rm -f -- "$entry"' EXIT
mkdir -m 700 "$test_dir/runtime"
bash "$project_root/tests/audio/audio-route.sh"
bash "$project_root/tests/audio/audio-devices.sh"
cat > "$entry" <<'QML'
import QtQuick
import Quickshell
Scope { Loader { source: "tests/audio/audio-smoke.qml" } }
QML
output=$(QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$entry" 2>&1) || {
    printf '%s\n' "$output" >&2
    exit 1
}
printf '%s\n' "$output"
[[ $output == *'PASS: audio panels'* && $output != *'AUDIO SMOKE FAIL:'* \
    && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
    && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]

if [[ ${1:-} == --native-imports ]]; then
    cat > "$entry" <<'QML'
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "src/modules/system/audio"
import "src"
import "src/bar"
import "src/services"
import "src/theme"
Scope {
    id: root
    property int step: 0
    Component { Bar {} }
    Item {
        Row {
            id: panels
            anchors.centerIn: parent
            spacing: 20
            AudioTooltip {}
            AudioTooltip { input: true }
        }
    }
    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.step++ < 3) return
            if (!Pipewire.ready || AudioService.outputs.length === 0 || AudioService.inputs.length === 0) {
                if (root.step > 25) { console.error("AUDIO NATIVE FAIL: PipeWire did not expose devices"); Qt.quit() }
                return
            }
            if (AudioService.sink !== Pipewire.defaultAudioSink || AudioService.source !== Pipewire.defaultAudioSource
                || !AudioService.outputs.every(node => node.audio && !node.isStream && node.isSink)
                || !AudioService.inputs.every(node => node.audio && !node.isStream && !node.isSink)) {
                console.error("AUDIO NATIVE FAIL: default binding or device filtering")
                Qt.quit()
                return
            }
            if (AudioService.cards.length === 0) {
                if (root.step > 25) { console.error("AUDIO NATIVE FAIL: card profiles not loaded"); Qt.quit() }
                return
            }
            for (const devices of [AudioService.outputDevices, AudioService.inputDevices]) {
                if (devices.some((node, index) => index > 0 && AudioService.deviceName(devices[index - 1]).localeCompare(AudioService.deviceName(node)) > 0)) {
                    console.error("AUDIO NATIVE FAIL: devices not sorted by name")
                    Qt.quit()
                    return
                }
            }
            if ([...AudioService.outputs, ...AudioService.inputs].some(node => node.properties["device.id"] && !AudioService.cardForNode(node))) {
                console.error("AUDIO NATIVE FAIL: card profiles not attached to existing hardware nodes")
                Qt.quit()
                return
            }
            console.log("LIVE AUDIO OUTPUTS: " + AudioService.outputs.map(node => AudioService.deviceName(node)).join(" | "))
            console.log("LIVE MICROPHONES: " + AudioService.inputDevices.map(node => AudioService.deviceName(node)).join(" | "))
            console.log("LIVE AUDIO PROFILES: " + AudioService.cards.map(card => card.description + ": " + card.profiles.length).join(" | "))
            for (const [direction, apps] of [["PLAYBACK", AudioService.playbackApps], ["RECORDING", AudioService.micApps]]) {
                console.log("LIVE " + direction + " APPS: " + JSON.stringify(apps.map(app => ({
                    name: app.name, serials: app.serials, device: app.deviceName,
                    multipleDevices: app.multipleDevices,
                    mutable: app.nodes.every(node => node.ready && !!node.audio), muted: AudioService.appMuted(app)
                }))))
            }
            console.log("PASS: full bar imports, live audio devices, system default bindings, native panels")
            Qt.quit()
        }
    }
}
QML
    native_output=$(QT_QPA_PLATFORM=wayland timeout 15 qs -p "$entry" 2>&1) || {
        printf '%s\n' "$native_output" >&2
        exit 1
    }
    printf '%s\n' "$native_output"
    [[ $native_output == *'PASS: full bar imports'* && $native_output != *'AUDIO NATIVE FAIL:'* \
        && $native_output != *'Failed to load configuration'* && $native_output != *'Binding loop detected'* \
        && $native_output != *'TypeError:'* && $native_output != *'ReferenceError:'* ]]
fi
