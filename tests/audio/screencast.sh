#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-screencast.XXXXXXXX)
server_pid=""
cleanup() {
    if [[ -n $server_pid ]]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$project_root/tests/audio/tst-screencast.qml" -o -,txt

if [[ ${1:-} == --native ]]; then
    # A private server prevents these disposable nodes from reaching the desktop.
    mkdir -m 700 "$test_dir/runtime"
    export XDG_RUNTIME_DIR="$test_dir/runtime" PIPEWIRE_RUNTIME_DIR="$test_dir/runtime"
    export PIPEWIRE_CORE=quickshell-capture-test PIPEWIRE_REMOTE=quickshell-capture-test
    pipewire > "$test_dir/pipewire.log" 2>&1 &
    server_pid=$!
    deadline=$((SECONDS + 5))
    until [[ -S $test_dir/runtime/quickshell-capture-test ]]; do
        if ! kill -0 "$server_pid" 2>/dev/null || ((SECONDS >= deadline)); then
            cat "$test_dir/pipewire.log" >&2; exit 1
        fi
        sleep 0.03
    done
    for name in banana potato; do
        timeout 5 pw-cli create-node spa-node-factory \
            "{ factory.name = support.node.driver node.name = capture-test-$name media.class = Stream/Input/Video application.name = $name object.linger = true }"
    done
    mkdir "$test_dir/sound-bin"
    printf '#!/bin/sh\nexit 0\n' > "$test_dir/sound-bin/canberra-gtk-play"
    chmod 700 "$test_dir/sound-bin/canberra-gtk-play"
    fixture_url=$(printf 'file://%s/tests/audio/screencast-panel-smoke.qml' "$project_root" | jq -Rs .)
    cat > "$test_dir/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: $fixture_url } }
QML
    output=$(QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 \
        XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
        PATH="$test_dir/sound-bin:$PATH" timeout 10 qs -p "$test_dir/shell.qml" 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *'PASS: native capture descriptions'* && $output != *'SCREENCAST FAIL:'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop detected'* ]]
    printf 'PASS: two disposable captures rendered on a private PipeWire server\n'
fi
