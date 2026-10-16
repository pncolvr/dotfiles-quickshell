#!/usr/bin/env bash
# Synthetic data, offscreen controls and mocked browsers; no real launches or private imports.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-webapps-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/bin" "$fixture/home"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
node - "$fixture/src/config/Config.qml" <<'JS'
const fs=require('node:fs'), file=process.argv[2];
const browsers=[
    {id:'qutebrowser',name:'Qutebrowser',command:['qutebrowser'],profiles:[{id:'qutebrowser-webapp',name:'Webapps'}],
        profileArguments:['--desktop-file-name','{profile}','-B','/test-data/{profile}'],reuseArguments:['--target','tab'],windowArguments:['--target','window']},
    {id:'vivaldi',name:'Vivaldi',command:['vivaldi'],profiles:[{id:'Test Profile',name:'Work'},{id:'Alternate Profile',name:'Personal'}],
        profileArguments:['--profile-directory={profile}'],windowArguments:['--new-window'],appArguments:['--app={url}']},
    {id:'default',name:'System default',command:['xdg-open']}
];
fs.writeFileSync(file,fs.readFileSync(file,'utf8').replace(/readonly property var webappBrowsers: \[[\s\S]*?\n    \]/,
    ()=> 'readonly property var webappBrowsers: '+JSON.stringify(browsers)));
JS
sed 's@"../../src@"src@g' "$repo/tests/webapps/manage.qml" > "$fixture/shell.qml"
cat > "$fixture/bin/browser" <<'SH'
#!/usr/bin/env bash
jq -cn --arg program "${0##*/}" --args '{program:$program,args:$ARGS.positional}' -- "$@" >> "$WEBAPP_TEST_DIR/actions"
if [[ ${1:-} == fail ]]; then exit 3; fi
SH
chmod +x "$fixture/bin/browser"
ln -s browser "$fixture/bin/qutebrowser"
ln -s browser "$fixture/bin/vivaldi"
ln -s browser "$fixture/bin/beforetest"
ln -s browser "$fixture/bin/aftertest"
export WEBAPP_TEST_DIR="$fixture" PATH="$fixture/bin:$PATH"
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
export QT_QPA_PLATFORMTHEME=generic XDG_CURRENT_DESKTOP=
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
for phase in setup restart; do
    WEBAPP_TEST_PHASE="$phase" timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: webapps' "$fixture/log" || rg -q 'WEBAPP FAIL:|TypeError:|ReferenceError:|Failed to load configuration|Binding loop' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
    rg 'PASS: webapps' "$fixture/log"
done
jq -se 'length==6 and any(.program=="qutebrowser" and (.args|index("--target"))!=null and (.args|index("tab"))!=null and (.args|index("window"))==null and .args[-1]=="https://example.test/window?x=1&y=2") and any(.program=="vivaldi" and .args==["--profile-directory=Test Profile","--app=https://example.test/app"])' "$fixture/actions" >/dev/null
jq -se 'any(.program=="beforetest" and .args==["literal $(not-executed)"]) and any(.program=="aftertest" and .args==["literal;argument"]) and all(.[]; all(.args[]; .!="https://example.test/must-not-open"))' "$fixture/actions" >/dev/null
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA user_version;') == 12 ]]
printf 'PASS: native browser argv and persistent webapps launch without old JSON/env files\n'
