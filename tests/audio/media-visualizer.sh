#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --native ]]; then
    exec dbus-run-session -- bash "$0" --private-native
fi
if [[ ${1:-} == --gpu ]]; then
    export MEDIA_VISUALIZER_GPU=1
    if [[ ${WAYLAND_DISPLAY:-} != /* ]]; then
        export WAYLAND_DISPLAY="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    fi
fi
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-visualizer.XXXXXXXX)
imports_entry=$(mktemp "$project_root/.media-imports.XXXXXXXX.qml")
test_pids=()
previous_window=""
previous_pointer=""
if [[ ${1:-} == --gpu ]] && command -v hyprctl >/dev/null; then
    previous_window=$(hyprctl -j activewindow | jq -r '.address // empty')
    previous_pointer=$(hyprctl -j cursorpos | jq -r '[.x,.y] | join(" ")')
fi
cleanup() {
    for pid in "${test_pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for pid in "${test_pids[@]}"; do wait "$pid" 2>/dev/null || true; done
    if [[ -n $previous_window ]]; then hyprctl dispatch focuswindow "address:$previous_window" >/dev/null 2>&1 || true; fi
    if [[ -n $previous_pointer ]]; then hyprctl dispatch movecursor "$previous_pointer" >/dev/null 2>&1 || true; fi
    rm -f -- "$imports_entry"
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
export XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
cat > "$test_dir/art.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="550" height="275"><defs><linearGradient id="gradient"><stop stop-color="#ff8800"/><stop offset="1" stop-color="#0088ee"/></linearGradient></defs><rect width="550" height="275" fill="url(#gradient)"/></svg>
SVG
export MEDIA_VISUALIZER_ART="$test_dir/art.svg"
if [[ ${1:-} == --private-native ]]; then
    export XDG_RUNTIME_DIR="$test_dir/runtime" PIPEWIRE_RUNTIME_DIR="$test_dir/runtime"
    export PIPEWIRE_CORE=quickshell-visualizer-test PIPEWIRE_REMOTE=quickshell-visualizer-test
    export XDG_CONFIG_HOME="$test_dir/config" XDG_STATE_HOME="$test_dir/state"
    export GIO_USE_VFS=local
    export MEDIA_VISUALIZER_NATIVE=1
    mkdir -p "$test_dir/config/wireplumber/wireplumber.conf.d"
    cat > "$test_dir/config/wireplumber/wireplumber.conf.d/isolated.conf" <<'CONF'
wireplumber.profiles = {
    main = {
        monitor.alsa = disabled
        monitor.bluez = disabled
        monitor.bluez-midi = disabled
        monitor.v4l2 = disabled
    }
}
CONF
    pipewire > "$test_dir/pipewire.log" 2>&1 &
    test_pids+=("$!")
    deadline=$((SECONDS + 5))
    until [[ -S $test_dir/runtime/quickshell-visualizer-test ]]; do
        if ! kill -0 "${test_pids[0]}" 2>/dev/null || ((SECONDS >= deadline)); then
            cat "$test_dir/pipewire.log" >&2; exit 1
        fi
        sleep 0.03
    done
    timeout 5 pw-cli create-node adapter '{ factory.name = support.null-audio-sink node.name = visualizer-sink media.class = Audio/Sink audio.position = [ FL FR ] object.linger = true }'
    wireplumber > "$test_dir/wireplumber.log" 2>&1 &
    test_pids+=("$!")
    python3 - "$test_dir/tone.wav" "$test_dir/other.wav" <<'PY'
import math
import struct
import sys
import wave
for path, frequency, volume in [(sys.argv[1], 220, 6000), (sys.argv[2], 4400, 18000)]:
    with wave.open(path, 'wb') as output:
        output.setparams((2, 2, 48000, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(struct.pack('<hh', *([int(volume * math.sin(i * 2 * math.pi * frequency / 48000))] * 2)) for i in range(48000 * 20)))
PY
    pw-cat --playback --target visualizer-sink --properties '{ application.name = Banana application.id = banana node.name = visualizer-test }' "$test_dir/tone.wav" > "$test_dir/playback.log" 2>&1 &
    test_pids+=("$!")
    pw-cat --playback --target visualizer-sink --properties '{ application.name = Potato application.id = potato node.name = unrelated-test }' "$test_dir/other.wav" > "$test_dir/other-playback.log" 2>&1 &
    test_pids+=("$!")
    sleep 0.5
fi
# Load through the bar's import chain in a fresh engine. Importing audio types
# directly first can hide inline-component resolution failures in the real shell.
cat > "$imports_entry" <<'QML'
import QtQml
import Quickshell
import "src/bar"
Scope {
    Component { RightModules {} }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            console.log("PASS: media visualizer through bar module imports")
            Qt.quit()
        }
    }
}
QML
imports_output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$imports_entry" 2>&1) || {
    printf '%s\n' "$imports_output" >&2; exit 1
}
[[ $imports_output == *'PASS: media visualizer through bar module imports'* && $imports_output != *'Failed to load configuration'* ]] || {
    printf '%s\n' "$imports_output" >&2; exit 1
}
printf 'PASS: media visualizer through bar module imports\n'

cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/audio/media-visualizer-smoke.qml" } }
QML
XDG_RUNTIME_DIR="$test_dir/runtime" bash "$project_root/src/services/audio/audio-spectrum.sh" --build >/dev/null
test_platform=offscreen
if [[ ${1:-} == --gpu ]]; then test_platform=wayland; fi
if [[ -n ${MEDIA_VISUALIZER_STYLE_DIR:-} ]]; then mkdir -p -- "$MEDIA_VISUALIZER_STYLE_DIR"; fi
output=$(QT_QPA_PLATFORM="$test_platform" QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 30 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: media flip'* && $output != *'VISUALIZER FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Error: Insufficient arguments'* && $output != *'Failed to compile shader'* && $output != *'Failed to build graphics pipeline'* && $output != *'no GLSL ES version in common'* ]]

# Reopen the same private database in a fresh engine to check durable selection.
cat > "$test_dir/shell.qml" <<QML
import QtQml
import Quickshell
import "file://$project_root/src/modules/system/audio"
import "file://$project_root/src/services" as Services
Scope {
    MediaVisualizer { id: restored; appId: "banana" }
    Component { id: visualizerFactory; MediaVisualizer {} }
    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            if (!Services.DbService.ready) return
            const another = visualizerFactory.createObject(restored, {appId:"banana"});
            const otherApp = visualizerFactory.createObject(restored, {appId:"potato"});
            let passed = restored.effect === "cava_spectrogram" && another.effect === restored.effect;
            passed = otherApp.effect === "wave" && restored.selectEffect("bars")
                && another.effect === "bars" && otherApp.effect === "wave" && passed;
            passed = otherApp.selectEffect("mirror") && restored.effect === "bars" && passed;
            another.appId = "potato";
            passed = another.effect === "mirror" && passed;
            another.appId = "banana";
            passed = another.effect === "bars" && passed;
            Services.PreferencesRepository.setValue(restored.effectPreferenceKey, "removed-style");
            passed = restored.effect === "wave" && another.effect === "wave" && otherApp.effect === "mirror" && passed;
            passed = !restored.selectEffect("removed-style") && passed;
            Services.PreferencesRepository.setValue("media.visualizer.effect", "ribbon");
            const newApp = visualizerFactory.createObject(restored, {appId:"new-app"});
            passed = newApp.effect === "ribbon" && restored.selectEffect("ribbon") && passed;
            Services.PreferencesRepository.setValue("media.visualizer.effect", "wave");
            passed = restored.effect === "ribbon" && newApp.effect === "wave" && otherApp.effect === "mirror" && passed;
            another.destroy();
            otherApp.destroy();
            newApp.destroy();
            console.log(passed ? "PASS: saved visualizer survives restart, applies to new cards and rejects unknown effects" : "VISUALIZER FAIL: saved effect");
            Qt.quit();
        }
    }
}
QML
saved_output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || {
    printf '%s\n' "$saved_output" >&2; exit 1
}
[[ $saved_output == *'PASS: saved visualizer'* && $saved_output != *'VISUALIZER FAIL:'* && $saved_output != *'Local database:'* ]] || {
    printf '%s\n' "$saved_output" >&2; exit 1
}
printf 'PASS: saved visualizer survives restart, applies to new cards and rejects unknown effects\n'

# Both app choices must remain independent after reopening the database again.
cat > "$test_dir/shell.qml" <<QML
import QtQml
import Quickshell
import "file://$project_root/src/modules/system/audio"
import "file://$project_root/src/services" as Services
Scope {
    MediaVisualizer { id: banana; appId: "banana" }
    MediaVisualizer { id: potato; appId: "potato" }
    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            if (!Services.DbService.ready) return
            console.log(banana.effect === "ribbon" && potato.effect === "mirror"
                ? "PASS: independent per-app visualizers survive restart" : "VISUALIZER FAIL: per-app restart");
            Qt.quit();
        }
    }
}
QML
apps_output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15 qs -p "$test_dir/shell.qml" 2>&1) || {
    printf '%s\n' "$apps_output" >&2; exit 1
}
[[ $apps_output == *'PASS: independent per-app visualizers'* && $apps_output != *'VISUALIZER FAIL:'* ]] || {
    printf '%s\n' "$apps_output" >&2; exit 1
}
printf 'PASS: independent per-app visualizers survive restart\n'
