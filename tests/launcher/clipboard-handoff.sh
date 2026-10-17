#!/usr/bin/env bash
# Private database, offscreen windows and mocked clipboard/desktop commands.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-clipboard-handoff.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/clipboard" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$HANDOFF_TEST_DIR/actions"
[[ $1 != paste ]] # Panel paste must never target the underlying desktop client.
MOCK
chmod +x "$fixture/clipboard"
node - "$fixture" <<'JS'
const fs=require('node:fs'),dir=process.argv[2],file=dir+'/src/config/Config.qml';
fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace(/readonly property var clipboardCommand:.*/, 'readonly property var clipboardCommand: '+JSON.stringify([dir+'/clipboard'])));
JS
sed 's@"../../src@"src@g' "$repo/tests/launcher/clipboard-handoff.qml" > "$fixture/shell.qml"
HANDOFF_TEST_DIR="$fixture" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 25 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: Clipboard preserves' "$fixture/log" \
    || rg -q 'HANDOFF FAIL:|TypeError:|ReferenceError:|Binding loop|Cannot assign|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
[[ $(rg -c '^restore$' "$fixture/actions") == 3 ]]
! rg -q '^paste$' "$fixture/actions"
