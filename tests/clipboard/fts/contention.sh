#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-contention.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$root_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed -i 's@readonly property var hyprlandHideApplicationsCommand:.*@readonly property var hyprlandHideApplicationsCommand: (active) => ["true"]@' "$fixture/src/config/Config.qml"
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/contention.qml" > "$fixture/shell.qml"
cat > "$fixture/read.sh" <<'READER'
#!/usr/bin/env bash
printf '.timeout 1000\nBEGIN;\nSELECT count(*) FROM clipboard;\n.shell sleep 0.2\nCOMMIT;\n' | sqlite3 -readonly "$1"
READER
CONTENTION_TEST_READER="$fixture/read.sh" QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
cat "$fixture/log"
rg -q 'PASS: capture/search contention' "$fixture/log"
! rg -q 'CONTENTION FAIL:|Local database failure:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"
