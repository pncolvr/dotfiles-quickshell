#!/usr/bin/env bash
# Real native picker and file loading; isolated bookmark data and a mock browser.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qs_bin=$(command -v qs)
fixture=$(mktemp -d /tmp/qs-bookmarks.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r" "$fixture/home" "$fixture/bin"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
node - "$fixture" <<'CONFIG'
const fs=require('node:fs'), fixture=process.argv[2];
const file=fixture+'/src/config/Config.qml';
let text=fs.readFileSync(file,'utf8');
text=text.replace(/readonly property bool browserRoutingEnabled: .*/, 'readonly property bool browserRoutingEnabled: false');
text=text.replace('clipboardMonitorEnabled: true','clipboardMonitorEnabled: false').replace(/readonly property bool bookmarksEnabled: .*/, 'property bool bookmarksEnabled: true').replace('workModeEnabled: true','workModeEnabled: false');
text=text.replace(/(readonly property string bookmarkFile:)[^\n]*/,()=> 'property string bookmarkFile: '+JSON.stringify(fixture+'/bookmarks'));
text=text.replace(/(readonly property var bookmarkBrowserCommand:)[^\n]*/,(_,prefix)=>prefix+' '+JSON.stringify([fixture+'/bin/browser with space','--profile=unchanged']));
fs.writeFileSync(file,text);
CONFIG
cat > "$fixture/bin/browser with space" <<'MOCK'
#!/usr/bin/env node
const fs=require('node:fs');
fs.appendFileSync(process.env.BOOKMARK_TEST_DIR+'/launches',JSON.stringify({args:process.argv.slice(2)})+'\n');
MOCK
cat > "$fixture/bin/qs" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected picker IPC\n' >> "$BOOKMARK_TEST_DIR/ipc"
exit 1
MOCK
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '[]\n'
MOCK
chmod +x "$fixture/bin/"*
sed 's@"../../src@"src@g' "$repo_dir/tests/launcher/bookmarks.qml" > "$fixture/shell.qml"
export BOOKMARK_TEST_DIR="$fixture" PATH="$fixture/bin:$PATH" HOME="$fixture/home"
export XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
run_fixture() {
    env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        timeout -k 1 15 "$qs_bin" -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: native Bookmarks' "$fixture/log" || rg -q 'BOOKMARK FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    rg 'PASS:' "$fixture/log"
}
run_fixture
rm -- "$fixture/bookmarks"
BOOKMARK_TEST_MISSING=1 run_fixture
[[ ! -e $fixture/ipc && ! -e $fixture/home/injected ]]
printf 'PASS: bookmark actions use literal configured argv and no picker bridge or shell interpolation\n'
