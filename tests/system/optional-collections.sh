#!/usr/bin/env bash
# Private storage and synthetic helpers only; no package manager or user files.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-optional-collections.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir -p "$fixture/data" "$fixture/cache" "$fixture/folder" "$fixture/new"
: > "$fixture/runs"
: > "$fixture/hold"
printf 'synthetic document\n' > "$fixture/document.txt"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
node - "$fixture" <<'JS'
const fs = require('fs'), path = process.argv[2] + '/src/config/Config.qml';
let source = fs.readFileSync(path, 'utf8');
const command = kind => `["bash", Quickshell.shellPath("helper.sh"), "${kind}"]`;
const values = {
    updatesEnabled: 'false', recentFilesEnabled: 'false',
    clipboardMonitorEnabled: 'false', workModeEnabled: 'false', browserRoutingEnabled: 'false',
    updatesCheckCommand: command('snapshot'), updatesRefreshCommand: command('refresh'),
    updatesInstallCommand: command('install'), defaultBrowserCommand: command('open-browser'),
    recentFileOpenCommand: command('open-file'), updatesScheduleDelay: '40', recentFilesRefreshInterval: '1000'
};
for (const [key, value] of Object.entries(values)) {
    const pattern = new RegExp(`readonly property (bool|var|int) ${key}:[^\\n]*`, 'g');
    if ([...source.matchAll(pattern)].length !== 1) throw Error(key);
    const mutable = ['updatesEnabled', 'recentFilesEnabled'].includes(key);
    source = source.replace(pattern, (_, type) => `${mutable ? '' : 'readonly '}property ${type} ${key}: ${value}`);
}
fs.writeFileSync(path, source);
JS
mkdir "$fixture/bin"
cat > "$fixture/bin/xdg-open" <<'MOCK'
#!/usr/bin/env bash
exec bash "$QS_COLLECTION_FIXTURE/helper.sh" open-notes
MOCK
chmod +x "$fixture/bin/xdg-open"
cat > "$fixture/src/services/system/NetworkService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool online: false }
QML
cat > "$fixture/helper.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
directory=${0%/*}
kind=$1
file=$(jq -nc --arg path "$directory/document.txt" '{path:$path,uri:("file://"+$path),name:"document.txt",icon:"text-x-generic",isDirectory:false}')
late() {
    printf 'stopped:%s\n' "$kind" >> "$directory/runs"
    case $kind in
        snapshot) printf 'core x86_64 stale 1 2\n' ;;
        folder) jq -nc --arg folder "$directory/new" --argjson file "$file" '{folder:$folder,files:[$file]}' ;;
        pins) jq -nc --arg uri "file://$directory/document.txt" '[$uri]' ;;
        import) jq -nc --argjson file "$file" '{files:[$file + {uri:"file:///stale",path:"/stale"}]}' ;;
    esac
    exit 0
}
trap late TERM
printf '%s\n' "$kind" >> "$directory/runs"
if [[ -s $directory/hold ]]; then printf 'ready:%s\n' "$kind" >> "$directory/runs"; fi
while [[ -s $directory/hold ]]; do sleep 0.02 & wait $!; done
case $kind in
    snapshot) printf 'core x86_64 fixture 1 2\n' ;;
    recent) jq -nc --argjson file "$file" '{files:[$file]}' ;;
    folder) jq -nc --arg folder "${2:-$directory/folder}" --argjson file "$file" '{folder:$folder,files:[$file]}' ;;
    pins) printf '[]\n' ;;
    import) jq -nc --argjson file "$file" '{files:[$file]}' ;;
esac
MOCK
cat > "$fixture/src/services/files/recent-files.sh" <<'MOCK'
exec bash "$QS_COLLECTION_FIXTURE/helper.sh" recent
MOCK
cat > "$fixture/src/services/files/folder-files.sh" <<'MOCK'
if [[ ${1:-} == --files ]]; then
    cat >/dev/null
    exec bash "$QS_COLLECTION_FIXTURE/helper.sh" import
fi
exec bash "$QS_COLLECTION_FIXTURE/helper.sh" folder "$2"
MOCK
cat > "$fixture/src/services/files/pinned-files.sh" <<'MOCK'
cat >/dev/null
exec bash "$QS_COLLECTION_FIXTURE/helper.sh" pins
MOCK
cp "$repo/tests/launcher/NativeFocusDriver.qml" "$fixture/NativeFocusDriver.qml"
sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$repo/tests/system/optional-collections.qml" > "$fixture/shell.qml"
for phase in disabled restart; do
    if [[ $phase == restart ]]; then
        sed -i 's/property bool updatesEnabled: false/property bool updatesEnabled: true/;s/property bool recentFilesEnabled: false/property bool recentFilesEnabled: true/' "$fixture/src/config/Config.qml"
    fi
    env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        PATH="$fixture/bin:$PATH" QS_COLLECTION_FIXTURE="$fixture" QS_COLLECTION_PHASE="$phase" XDG_RUNTIME_DIR="$fixture/runtime" \
        XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
        timeout -k 2 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: optional Updates and Recent Files' "$fixture/log" \
        || rg -q 'COLLECTION FAIL:|TypeError:|ReferenceError:|Binding loop|WARN scene|Failed to load configuration' "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    rg 'PASS:' "$fixture/log"
done
