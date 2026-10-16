#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: pulse shader check requires a native Wayland GPU surface\n'
    exit 0
fi
test_dir=$(mktemp -d /tmp/quickshell-pulse.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
# Runtime switches are mutable only in this isolated synthetic fixture.
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
sed -i -E 's/readonly property bool (animationsEnabled|micPulseEnabled):.*/property bool \1: true/;s/readonly property bool animateDuringScreenShare:.*/property bool animateDuringScreenShare: false/' "$test_dir/src/config/Config.qml"
sed -i 's/readonly property bool screencastActive:.*/property bool screencastActive: false/' "$test_dir/src/services/audio/AudioService.qml"
sed 's@"../../src@"src@g' "$project_root/tests/qml/pulse-smoke.qml" > "$test_dir/shell.qml"
output=$(QT_QPA_PLATFORM=wayland timeout -k 2 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
printf '%s\n' "$output"
[[ $output == *'PASS: GPU pulse'* && $output == *'PASS: disabling pulse'* \
    && $output == *'PASS: hidden text'* && $output == *'PASS: hidden window'* \
    && $output == *'PASS: showing the window'* \
    && $output == *'PASS: status shader'* && $output == *'PASS: status switch'* \
    && $output == *'PASS: staggered pulses'* && $output == *'PASS: resumed pulse rejoins'* \
    && $output != *'PULSE FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* \
    && $output != *'Failed to load configuration'* && $output != *'Failed to load shader'* ]]
