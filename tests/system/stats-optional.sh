#!/usr/bin/env bash
# Private offscreen panel and synthetic collector; no bandwhich or network capture.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-stats-optional.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -Ei 's/readonly property bool statsNetworkEnabled: (true|false)/property bool statsNetworkEnabled: false/;s/readonly property var statsProcessesCommand:/property var statsProcessesCommand:/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/collector.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
report='{"timestamp":10,"clockTicks":100,"processes":[{"pid":100,"name":"Synthetic","ticks":100,"start":"1","memory":4096,"down":1,"up":1}]}'
if [[ $1 == network ]]; then
    trap 'printf "network\n" >> "${0%/*}/stopped"; printf "%s\n" "$report"; exit 0' TERM
    while true; do sleep 0.05 & wait $!; done
fi
printf '%s\n' "$report"
MOCK
sed 's@"../../src@"src@g' "$repo/tests/system/stats-optional.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { tail -70 "$fixture/log"; exit 1; }
if ! rg -q 'PASS: optional Stats Network' "$fixture/log" || rg -q 'STATS OPTIONAL FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    tail -70 "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
