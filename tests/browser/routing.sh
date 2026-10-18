#!/usr/bin/env bash
# Private database, mock browsers and offscreen panels. No desktop integration installed.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-browser-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime" "$fixture/home"
mkdir "$fixture/bin"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
cat > "$fixture/bin/browser" <<'MOCK'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$BROWSER_TEST_DIR/actions"
MOCK
chmod +x "$fixture/bin/browser"
cat > "$fixture/bin/twitch" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$fixture/bin/twitch"
cat > "$fixture/bin/curl" <<'MOCK'
#!/usr/bin/env bash
case ${@: -1} in
    */cycle-a) printf 'https://jump.test/cycle-b';;
    */cycle-b) printf 'https://jump.test/cycle-a';;
    *) printf 'https://wrapped.test/?destination=https%%3A%%2F%%2Fsub.work.test%%2Fredirected';;
esac
MOCK
chmod +x "$fixture/bin/curl"
node - "$fixture" <<'JS'
const fs=require('node:fs'),dir=process.argv[2],file=dir+'/src/config/Config.qml';
let text=fs.readFileSync(file,'utf8').replace('clipboardMonitorEnabled: true','clipboardMonitorEnabled: false');
for(const [key,value] of Object.entries({browserRoutingEnabled:'true',browserHistoryEnabled:'true',browserWorkspaceFocusEnabled:'false',browserHistoryLimit:'100',twitchEnabled:'true'}))
 text=text.replace(new RegExp('readonly property (bool|int) '+key+':[^\\n]*'),(_,type)=>'property '+type+' '+key+': '+value);
text=text.replace(/readonly property string bookmarkFile:[^\n]*/,'property string bookmarkFile: '+JSON.stringify(dir+'/bookmarks'));
text=text.replace(/readonly property string webappDefaultBrowser:[^\n]*/,'property string webappDefaultBrowser: "b"');
text=text.replace(/readonly property var webappBrowsers: \[[\s\S]*?\n    \]/,'readonly property var webappBrowsers: '+JSON.stringify([
{id:'a',name:'A',command:[dir+'/bin/browser'],profiles:[{id:'work',name:'Work'}],profileArguments:['--profile={profile}'],reuseArguments:['--target','tab']},
{id:'b',name:'B',command:[dir+'/bin/browser','--browser=b']} ]));
fs.writeFileSync(file,text);
JS
printf 'https://one.test First\nhttps://two.test Second\n' > "$fixture/bookmarks"
mkdir -p "$fixture/data/applications"
cat > "$fixture/data/applications/fixture-application.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Fixture Application
Exec=$fixture/bin/browser --desktop %U
Categories=Utility;
DESKTOP
: > "$fixture/actions"
sed 's@"../../src@"src@g' "$repo/tests/browser/routing.qml" > "$fixture/shell.qml"
for phase in setup restart; do
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
    BROWSER_TEST_PHASE="$phase" \
    PATH="$fixture/bin:$PATH" BROWSER_TEST_DIR="$fixture" HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" QT_QPA_PLATFORM=offscreen \
    QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=generic QT_NO_XDG_DESKTOP_PORTAL=1 \
    timeout 25 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: browser' "$fixture/log" || rg -q 'BROWSER FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
rg 'PASS:' "$fixture/log"
done
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA user_version; PRAGMA integrity_check;') == $'16\nok' ]]
sqlite3 "$fixture/data/quickshell.db" "INSERT INTO browser_history_fts(browser_history_fts,rank) VALUES('integrity-check',1);"
