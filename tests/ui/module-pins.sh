#!/usr/bin/env bash
# All desktop actions use stubs; synthetic Qt clicks never move the real cursor.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-module-pins.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/bin"
cat > "$fixture/bin/xdg-open" <<'MOCK'
#!/usr/bin/env bash
printf 'notes\n' >> "$PIN_TEST_ACTIONS"
MOCK
chmod +x "$fixture/bin/xdg-open"
cat > "$fixture/install.sh" <<'MOCK'
printf 'install\n' >> "$PIN_TEST_ACTIONS"
MOCK
node - "$fixture" <<'JS'
const fs = require('fs'), file = process.argv[2] + '/src/config/Config.qml';
let source = fs.readFileSync(file, 'utf8');
const values = {
    updatesCheckCommand: '["printf", "core x86_64 linux 1 2\\n"]',
    updatesInstallCommand: '["bash", Quickshell.shellPath("install.sh")]',
    networkCheckCommand: '["true"]', networkVpnCommand: '["true"]'
};
for (const [key, value] of Object.entries(values)) {
    const expression = new RegExp('(readonly property var ' + key + ':)[^\\n]*', 'g');
    if ([...source.matchAll(expression)].length !== 1) throw Error(key);
    source = source.replace(expression, (_, declaration) => declaration + ' ' + value);
}
fs.writeFileSync(file, source);
JS
cat > "$fixture/src/services/recording/RecordingService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject {
    property string state: "recording"
    readonly property bool active: ["recording", "stopping", "recovering"].includes(state)
    readonly property string filename: "/tmp/synthetic recording.mp4"
}
QML
sed 's@"../../src@"src@g' "$repo_dir/tests/ui/module-pins.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY PATH="$fixture/bin:$PATH" PIN_TEST_ACTIONS="$fixture/actions" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 15 qs -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: all 14' "$fixture/log" \
    || rg -q 'PIN FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
# The 14 icon clicks must never install anything; only the two panel buttons act.
[[ $(sort "$fixture/actions") == $'install\nnotes' ]]
rg 'PASS:' "$fixture/log"
