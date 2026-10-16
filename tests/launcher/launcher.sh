#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
placement_display=${WAYLAND_DISPLAY:-}
if [[ -n $placement_display && $placement_display != /* ]]; then placement_display="${XDG_RUNTIME_DIR:?}/$placement_display"; fi
test_dir=$(mktemp -d /tmp/quickshell-picker-test.XXXXXXXX)
shell_pid=""; client_pid=""
cleanup() {
    [[ -z $client_pid ]] || kill "$client_pid" 2>/dev/null || true
    [[ -z $shell_pid ]] || { kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; }
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache" "$test_dir/bin"
# Clipboard acceptance must never alter the real desktop clipboard or inject keys.
cat > "$test_dir/bin/wl-copy" <<'MOCK'
#!/usr/bin/env bash
cat > "$PICKER_COPY_TEST_DIR/copied"
MOCK
cat > "$test_dir/bin/ydotool" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$PICKER_COPY_TEST_DIR/injected"
MOCK
cat > "$test_dir/bin/gtk-launch" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$PICKER_COPY_TEST_DIR/app-arguments"
if [[ -v ELECTRON_RUN_AS_NODE ]]; then
    printf 'inherited\n' > "$PICKER_COPY_TEST_DIR/app-environment"
else
    printf 'unset\n' > "$PICKER_COPY_TEST_DIR/app-environment"
fi
MOCK
chmod +x "$test_dir/bin/wl-copy" "$test_dir/bin/ydotool" "$test_dir/bin/gtk-launch"
export PICKER_COPY_TEST_DIR="$test_dir" PATH="$test_dir/bin:$PATH"
mkdir -p "$test_dir/data/applications"
cat > "$test_dir/data/applications/picker-test.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Picker Test
Exec=true
Terminal=false
DESKTOP
# Never copy private provider configuration into the test shell.
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
cp "$project_root/provider-config.qml" "$test_dir/"
sed -Ei 's/readonly property int clipboardMaxItems: [0-9]+/readonly property int clipboardMaxItems: 3/' "$test_dir/src/config/Config.qml"
sed -Ei 's/readonly property int clipboardMaxTotalBytes: [0-9]+/readonly property int clipboardMaxTotalBytes: 24/' "$test_dir/src/config/Config.qml"
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
sed -i 's/readonly property bool pickerShowPrompt: false/readonly property bool pickerShowPrompt: true/' "$test_dir/src/config/Config.qml"
node - "$test_dir/src/config/Config.qml" "$test_dir/wallpapers" "$test_dir/saved-wallpapers" <<'JSCONFIG'
const fs = require('fs'), [file, images, saved] = process.argv.slice(2);
let source = fs.readFileSync(file,'utf8');
for (const [name,value] of Object.entries({wallpaperDirectory:images,wallpaperStateDirectory:saved}))
    source = source.replace(new RegExp('(readonly property string '+name+':)[^\\n]*'),
        (_, declaration) => declaration+' '+JSON.stringify(value));
fs.writeFileSync(file,source);
JSCONFIG
mkdir -p "$test_dir/data/clipboard"
sqlite3 "$test_dir/data/quickshell.db" <<'SQL'
CREATE TABLE clipboard (id TEXT PRIMARY KEY, mime TEXT NOT NULL, kind TEXT NOT NULL, bytes INTEGER NOT NULL, text TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL);
INSERT INTO clipboard VALUES ('dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd', 'text/plain', 'text', 6, 'legacy', 1);
PRAGMA user_version=5;
SQL
printf 'hello\nworld\n' > "$test_dir/data/clipboard/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
sed 's@"../../src@"src@g' "$project_root/tests/launcher/launcher-smoke.qml" > "$test_dir/shell.qml"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=4
picker="$test_dir/src/services/launcher/launcher.sh"
ipc() { qs ipc -p "$test_dir" "$@"; }
start() {
    ELECTRON_RUN_AS_NODE=1 qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
    for ((try=0;try<80;try++)); do
        if rg -q 'PASS: picker' "$test_dir/log"; then return; fi
        if ! kill -0 "$shell_pid" 2>/dev/null; then cat "$test_dir/log"; exit 1; fi
        sleep 0.05
    done
    cat "$test_dir/log"; exit 1
}
wait_open() {
    for ((try=0;try<60;try++)); do
        if snapshot | jq -e --arg kind "${1:-bridge}" '.visible and ($kind == "native" or (.directory|length > 0))' >/dev/null; then return; fi
        sleep 0.025
    done
    cat "$test_dir/log"; exit 1
}
snapshot() {
    local state
    for ((try=0;try<200;try++)); do
        state=$(ipc call pickertest snapshot)
        if jq -e '.searchPending | not' <<< "$state" >/dev/null; then
            printf '%s\n' "$state"
            return
        fi
        sleep 0.01
    done
    cat "$test_dir/log" >&2
    return 1
}
wait_client() {
    client_exit=0; wait "$client_pid" || client_exit=$?; client_pid=""
    [[ $client_exit == "$1" ]] || { cat "$test_dir/client-error"; printf 'Unexpected client exit: %s\n' "$client_exit"; exit 1; }
}
start
bash "$picker" --provider-config | jq -e --arg images "$test_dir/wallpapers" --arg saved "$test_dir/saved-wallpapers" \
    '.WALLPAPER_DIRECTORY == $images and .WALLPAPER_STATE_DIRECTORY == $saved and .WORKING_STATE_NAME == "work"' >/dev/null
printf 'PASS: live launcher exports the same shared Config settings without opening a picker\n'
ipc call pickertest launchTestApplication
for ((try=0;try<100;try++)); do
    [[ -f $test_dir/app-environment ]] && break
    sleep 0.02
done
[[ $(<"$test_dir/app-environment") == unset ]]
[[ $(<"$test_dir/app-arguments") == picker-test ]]
printf 'PASS: application launch strips inherited Electron Node mode and preserves the desktop entry ID\n'
history_plan=$(sqlite3 "$test_dir/data/quickshell.db" 'EXPLAIN QUERY PLAN SELECT id, mime, kind, bytes, text, updated_at, pinned FROM clipboard ORDER BY updated_at DESC, id DESC;')
[[ $history_plan == *clipboard_updated_at* && $history_plan != *'TEMP B-TREE'* ]]
ipc call pickertest windowFocusCommand 0x2 > "$test_dir/focus-window.lua"
lua - "$test_dir/focus-window.lua" <<'LUA'
local file = assert(io.open(arg[1]))
local source = file:read("*a")
file:close()
local calls, clients = {}, {}
hl = {
    get_windows = function() return clients end,
    dispatch = function(action) action() end,
    dsp = {
        group = {active = function(options) return function()
            local group = options.window.group
            group.current = group.members[options.index]
            table.insert(calls, "tab:" .. group.current.address)
        end end},
        focus = function(options) return function()
            assert(not options.window.group or options.window.group.current == options.window,
                "focus must activate the selected group member first")
            table.insert(calls, "focus:" .. options.window.address)
        end end,
    },
}
local focus = assert(load("return " .. source))()
local target = {address = "0x2", mapped = true}
local sibling = {address = "0x1", mapped = true}
clients = {sibling, target}
local group = {members = {sibling, target}, current = sibling}
target.group, sibling.group = group, group
focus()
assert(table.concat(calls, ",") == "tab:0x2,focus:0x2", "selected group tab")
calls, group.members, group.current = {}, {target, sibling}, sibling
focus()
assert(table.concat(calls, ",") == "tab:0x2,focus:0x2", "live reordered group membership")
calls, target.group = {}, nil
focus()
assert(table.concat(calls, ",") == "focus:0x2", "ungrouped window")
calls, clients = {}, {sibling}
focus()
assert(#calls == 0, "closed window must not focus a sibling")
clients, target.mapped = {target}, false
focus()
assert(#calls == 0, "unmapped window must not be focused")
print("PASS: window activation selects the exact group member before focus, resolves reordered groups, and skips closed/unmapped windows")
LUA
printf '%s\n' '{"allowTyped":false,"items":[{"title":"Same","result":"first"},{"title":"Same","result":{"path":"second"}}]}' > "$test_dir/options.json"
bash "$picker" --json "$test_dir/options.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest accept 1
wait_client 0
[[ $(<"$test_dir/result") == '{"path":"second"}' ]]

# Legacy pointer-preservation options remain accepted; all launchers preserve it.
for request_type in json json-true dmenu; do
    if [[ $request_type == json || $request_type == json-true ]]; then
        jq -n --argjson oldOption "$([[ $request_type == json-true ]] && printf true || printf false)" \
            '{movePointer:$oldOption,items:[{title:"Keep pointer",result:"kept"}]}' > "$test_dir/pointer-options.json"
        bash "$picker" --json "$test_dir/pointer-options.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    else
        printf 'kept\n' | bash "$picker" --dmenu --keep-pointer > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    fi
    wait_open
    ipc call pickertest enter
    wait_client 0
    [[ $(<"$test_dir/result") == kept ]]
done
printf 'PASS: legacy JSON and dmenu pointer options remain compatible\n'

# QR generation opens the actual viewer and retains the clipboard after Enter or Escape.
qr_text='literal | Olá "quoted" $value'
for close_action in enter pressEscape; do
    bash "$picker" provider encode-qrcode > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open native
    wait_client 0
    snapshot | jq -e '.items == [] and .query == "" and (.canAccept | not)
        and .emptyHint == "" and (.emptyHintVisible | not) and .placeholder == "Text to encode"
        and .listHeight == 0 and .listImplicitHeight == 0
        and .footerHint == "Enter to generate qr code · Esc to cancel"' >/dev/null
    ipc call pickertest query '   '
    snapshot | jq -e '(.canAccept | not) and (.emptyHintVisible | not)' >/dev/null
    ipc call pickertest query "$qr_text"
    snapshot | jq -e '.canAccept and (.emptyHintVisible | not)' >/dev/null
    ipc call pickertest enter
    for ((try=0;try<80;try++)); do
        if snapshot | jq -e '.imageOnly and .previewStatus == 1' >/dev/null; then break; fi
        sleep 0.025
    done
    snapshot | jq -e '.imageOnly and .previewStatus == 1 and (.previewSmooth | not)
        and (.previewMipmap | not) and .previewWidth > 0 and (.previewWidth % .sourceWidth == 0)
        and .panelHeight <= 360 and .viewerHints == 0' >/dev/null
    snapshot | jq -r '.previewSource' | node -e 'let data="";process.stdin.on("data",chunk=>data+=chunk);process.stdin.on("end",()=>process.stdout.write(Buffer.from(data.trim().split(",")[1],"base64")));' > "$test_dir/preview-qr.png"
    printf '%s' "$qr_text" | qrencode --type=PNG -o "$test_dir/expected-qr.png"
    cmp "$test_dir/expected-qr.png" "$test_dir/copied"
    cmp "$test_dir/preview-qr.png" "$test_dir/copied"
    ipc call pickertest "$close_action"
    snapshot | jq -e '.items == []' >/dev/null
    cmp "$test_dir/expected-qr.png" "$test_dir/copied"
done
rm "$test_dir/copied"
bash "$picker" provider encode-qrcode > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open native
wait_client 0
ipc call pickertest pressEscape
[[ ! -f $test_dir/copied ]]
printf 'PASS: QR input has no redundant hint, displays the copied PNG sharply and preserves clipboard content after viewer dismissal\n'

# Wallpaper image previews use bounded native image loading on wide and narrow screens.
mkdir "$test_dir/wallpapers"
magick -size 160x90 xc:red "$test_dir/wallpapers/one.png"
jq -n --arg image "file://$test_dir/wallpapers/one.png" '{
    previewImages:true,allowTyped:false,items:[{title:"One",image:$image,result:"one"},{title:"Two",image:$image,result:"two"}]
}' > "$test_dir/images.json"
for viewport in 500 1000; do
    ipc call pickertest imageViewport "$viewport" 400
    bash "$picker" --json "$test_dir/images.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    for ((try=0;try<80;try++)); do
        if snapshot | jq -e '.previewImages and .previewStatus == 1' >/dev/null; then break; fi
        sleep 0.025
    done
    snapshot | jq -e --arg image "file://$test_dir/wallpapers/one.png" --argjson viewport "$viewport" \
        '.previewStatus == 1 and .previewSource == $image and .stackedPreview == ($viewport < 800)
            and (.rowImageSources | length == 2 and all(.[]; . == ""))' >/dev/null
    ipc call pickertest query 'missing image'
    snapshot | jq -e '.filtered == [] and .previewSource == ""' >/dev/null
    ipc call pickertest pressEscape
    wait_client 1
done
jq '.previewImages = false' "$test_dir/images.json" > "$test_dir/row-images.json"
bash "$picker" --json "$test_dir/row-images.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e --arg image "file://$test_dir/wallpapers/one.png" \
    '.rowImageSources | length == 2 and all(.[]; . == $image)' >/dev/null
ipc call pickertest pressEscape
wait_client 1
ipc call pickertest imageViewport 560 550
bash "$picker" --json "$test_dir/options.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.previewImages == false and .previewSource == ""' >/dev/null
ipc call pickertest pressEscape
wait_client 1
printf 'PASS: image picker loads only the large preview, keeps rows free of image sources and preserves ordinary menu thumbnails\n'

# Browse repeatedly; selecting mode and monitor must not lose the image or its search.
mkdir "$test_dir/wallpaper-bin"
cat > "$test_dir/wallpaper-bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' '[{"name":"DP-1","focused":false},{"name":"HDMI-A-1","focused":true}]'
MOCK
cat > "$test_dir/wallpaper-bin/awww" <<'MOCK'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$PICKER_COPY_TEST_DIR/wallpaper-calls"
MOCK
chmod +x "$test_dir/wallpaper-bin/"*
wait_wallpaper_step() {
    local key=$1
    for ((try=0;try<100;try++)); do
        if snapshot | jq -e --arg key "$key" '.visible and (.directory|length > 0) and .selectionKey==$key' >/dev/null; then return; fi
        sleep 0.025
    done
    cat "$test_dir/log" "$test_dir/client-error" >&2
    return 1
}
PATH="$test_dir/wallpaper-bin:$PATH" \
    bash "$picker" provider wallpaper > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_wallpaper_step wallpaper.image
ipc call pickertest query one
ipc call pickertest enter
wait_wallpaper_step wallpaper.mode
snapshot | jq -e '[.items[].result]==["personal","work"]' >/dev/null
ipc call pickertest accept 1
wait_wallpaper_step wallpaper.monitor
snapshot | jq -e '[.items[].result]==["HDMI-A-1","DP-1"]' >/dev/null
ipc call pickertest accept 1
wait_wallpaper_step wallpaper.image
snapshot | jq -e '.query=="one" and (.filtered[.currentIndex].result|endswith("/one.png"))' >/dev/null
[[ $(readlink "$test_dir/saved-wallpapers/wallpaper_work_1") == "$test_dir/wallpapers/one.png" ]]
# Both child cancellations return to the same image and filter.
ipc call pickertest enter
wait_wallpaper_step wallpaper.mode
ipc call pickertest pressEscape
wait_wallpaper_step wallpaper.image
snapshot | jq -e '.query=="one" and .filtered[.currentIndex].title=="one.png"' >/dev/null
ipc call pickertest enter
wait_wallpaper_step wallpaper.mode
ipc call pickertest enter
wait_wallpaper_step wallpaper.monitor
ipc call pickertest pressEscape
wait_wallpaper_step wallpaper.image
snapshot | jq -e '.query=="one" and .filtered[.currentIndex].title=="one.png"' >/dev/null
ipc call pickertest pressEscape
wait_client 0
jq -se 'length==1 and .[0][0]=="img"' "$test_dir/wallpaper-calls" >/dev/null
printf 'PASS: wallpaper browsing preserves image/search through mode, monitor, application and child cancellation\n'

# External search flags must not override the shared Config.qml settings.
printf '%s\n' '{"fuzzy":false,"smartCase":false,"allowTyped":false,"items":[{"title":"Banana","result":"fruit"},{"title":"Potato","result":"vegetable"}]}' > "$test_dir/search.json"
bash "$picker" --json "$test_dir/search.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest query bna
snapshot | jq -e '.filtered | length == 1 and .[0].title == "Banana"' >/dev/null
ipc call pickertest query BNA
snapshot | jq -e '.filtered | length == 1 and .[0].title == "Banana"' >/dev/null
ipc call pickertest query bNa
snapshot | jq -e '.filtered | length == 0' >/dev/null
ipc call pickertest query bna
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == fruit ]]

printf 'Tomato\nPotato\n' | bash "$picker" --dmenu -i -sorting-method normal -no-custom > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest query TMT
snapshot | jq -e '.filtered | length == 1 and .[0].title == "Tomato"' >/dev/null
ipc call pickertest query tMt
snapshot | jq -e '.filtered | length == 0' >/dev/null
ipc call pickertest query tmt
snapshot | jq -e '.filtered | length == 1 and .[0].title == "Tomato"' >/dev/null
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == Tomato ]]
printf 'PASS: JSON and dmenu use shared fuzzy search and cannot override case or matching settings\n'

# Restore accepted results by identity, with independent history for each step.
printf '%s\n' '{"selectionKey":"test.menu","allowTyped":false,"items":[{"title":"Banana","result":"banana"},{"title":"Potato","result":"potato"},{"title":"Tomato","result":"tomato"}]}' > "$test_dir/remember.json"
bash "$picker" --json "$test_dir/remember.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 0' >/dev/null
ipc call pickertest accept 2
wait_client 0
bash "$picker" --json "$test_dir/remember.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 2 and .filtered[.currentIndex].result == "tomato" and .query == ""' >/dev/null
ipc call pickertest pressEscape
wait_client 1
jq '.items = [.items[1], .items[2], .items[0]]' "$test_dir/remember.json" > "$test_dir/reordered.json"
bash "$picker" --json "$test_dir/reordered.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 1 and .filtered[.currentIndex].result == "tomato"' >/dev/null
ipc call pickertest pressEscape
wait_client 1

for project in banana potato; do
    printf 'Open folder\nBanana\nTomato\n' | bash "$picker" --dmenu -no-custom --selection-key "projects.workspaces:$project" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    snapshot | jq -e '.currentIndex == 0 and .items[0].title == "Open folder"' >/dev/null
    if [[ $project == banana ]]; then ipc call pickertest accept 2; else ipc call pickertest enter; fi
    wait_client 0
done
printf 'Open folder\nBanana\nTomato\n' | bash "$picker" --dmenu -no-custom --selection-key projects.workspaces:banana > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 2 and .items[0].title == "Open folder"' >/dev/null
ipc call pickertest pressEscape
wait_client 1
jq '.items |= map(select(.result != "tomato"))' "$test_dir/remember.json" > "$test_dir/missing.json"
bash "$picker" --json "$test_dir/missing.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 0' >/dev/null
ipc call pickertest pressEscape
wait_client 1
printf 'PASS: remembered choices survive cancellation and row reordering, stay separate per project and fall back when removed\n'

printf 'Alpha\nbeta\ngamma\n' | bash "$picker" --dmenu -multi-select -case-smart -p Test > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest select 0
ipc call pickertest select 2
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == $'Alpha\ngamma' ]]

printf '%s\n' '{"action":"default","allowMultipleSelection":true,"items":[{"title":"Alpha","result":"a"},{"title":"Beta","result":"b"},{"title":"Gamma","result":"g"}]}' > "$test_dir/links.json"
bash "$picker" --json "$test_dir/links.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.acceptLabel == "Open links" and .canAccept and .selected == []' >/dev/null
ipc call pickertest pasteFixture false | jq -e '.' >/dev/null
snapshot | jq -e '.query == "Beta" and .selected == []' >/dev/null
ipc call pickertest query 'Prefix '
ipc call pickertest pasteFixture false | jq -e '.' >/dev/null
snapshot | jq -e '.query == "Prefix Beta" and .selected == []' >/dev/null
ipc call pickertest pasteFixture true | jq -e '.' >/dev/null
snapshot | jq -e '.query == "Beta" and .selected == []' >/dev/null
printf 'PASS: native Ctrl+V inserts clipboard text at the cursor and replaces selected text\n'
ipc call pickertest query Alpha
ipc call pickertest clickControl pickerSelectVisible | jq -e '.' >/dev/null
snapshot | jq -e '.selected == ["0"]' >/dev/null
ipc call pickertest toggleEntry
snapshot | jq -e '.selected == [] and .query == "Alpha"' >/dev/null
ipc call pickertest toggleEntry
ipc call pickertest typeSpace
snapshot | jq -e '.selected == ["0"] and .query == "Alpha "' >/dev/null
ipc call pickertest query Beta
ipc call pickertest toggleVisible
snapshot | jq -e '.selected == ["0","1"]' >/dev/null
ipc call pickertest toggleVisible
snapshot | jq -e '.selected == [] and .canAccept' >/dev/null
ipc call pickertest query 'no matching link'
ipc call pickertest enter
snapshot | jq -e '.visible and .selected == [] and (.canAccept | not)' >/dev/null
ipc call pickertest query ''
snapshot >/dev/null
ipc call pickertest down
ipc call pickertest toggleEntry
snapshot | jq -e '.selected == ["1"] and .currentIndex == 2' >/dev/null
ipc call pickertest clearSelection
snapshot | jq -e '.selected == [] and .query == ""' >/dev/null
ipc call pickertest query Beta
ipc call pickertest clickControl pickerSelectVisible | jq -e '.' >/dev/null
ipc call pickertest clickControl pickerAccept | jq -e '.' >/dev/null
wait_client 0
[[ $(<"$test_dir/result") == b ]]
for activation in keyboard button; do
    bash "$picker" --json "$test_dir/links.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    if [[ $activation == keyboard ]]; then ipc call pickertest down; else ipc call pickertest query Beta; fi
    snapshot | jq -e '.selected == [] and .canAccept and .filtered[.currentIndex].result == "b"' >/dev/null
    if [[ $activation == keyboard ]]; then ipc call pickertest enter; else ipc call pickertest clickControl pickerAccept | jq -e '.' >/dev/null; fi
    wait_client 0
    [[ $(<"$test_dir/result") == b ]]
done
printf 'PASS: mouse/keyboard selection, search typing, filtered selection toggle, clear all, selected-entry submission and highlighted-row fallback with Enter/button\n'

ipc call pickertest clipboardFixture
ipc call pickertest query 'delete me'
snapshot | jq -e '.filtered | length == 1' >/dev/null
ipc call pickertest togglePin
snapshot | jq -e '.query == "delete me" and .filtered[0].pinned' >/dev/null
ipc call pickertest deleteEntry
snapshot | jq -e '.query == "delete me" and .filtered == [] and (.items | length) == 0' >/dev/null
ipc call pickertest query ''
snapshot >/dev/null
ipc call pickertest togglePin
snapshot | jq -e '.query == "" and .items[0].pinned and .currentIndex == 0' >/dev/null
ipc call pickertest clickControl pinClipboardEntry | jq -e '.' >/dev/null
snapshot | jq -e '(.items[0].pinned | not)' >/dev/null
ipc call pickertest togglePin
ipc call pickertest clipboardFixture
ipc call pickertest togglePinnedOnly
snapshot | jq -e '.itemCriteria.pinned and (.filtered | length) == 1 and .filtered[0].pinned and (.items | length) == 1' >/dev/null
ipc call pickertest query 'delete me'
snapshot | jq -e '.filtered == [] and (.canAccept | not)' >/dev/null
ipc call pickertest togglePinnedOnly
snapshot | jq -e '.itemCriteria == {} and .query == "delete me" and (.filtered | length) == 1 and (.filtered[0].pinned | not)' >/dev/null
ipc call pickertest query hello
ipc call pickertest togglePinnedOnly
snapshot >/dev/null
ipc call pickertest togglePin
snapshot | jq -e '.itemCriteria.pinned and .query == "hello" and .filtered == [] and (.canAccept | not)' >/dev/null
ipc call pickertest togglePinnedOnly
snapshot >/dev/null
ipc call pickertest togglePin
ipc call pickertest query ''
snapshot >/dev/null
ipc call pickertest clickControl clipboardPinnedOnly | jq -e '.' >/dev/null
snapshot | jq -e '.itemCriteria.pinned and (.filtered | length) == 1 and .filtered[0].pinned' >/dev/null
ipc call pickertest clickControl clipboardPinnedOnly | jq -e '.' >/dev/null
snapshot | jq -e '.itemCriteria == {} and (.filtered | length) == 2' >/dev/null
ipc call pickertest togglePinnedOnly
ipc call pickertest clipboardFixture
snapshot | jq -e '.itemCriteria == {} and (.filtered | length) == 2' >/dev/null
printf 'PASS: pinned-only keyboard/button toggle, combined search, unpinning while filtered, empty results and reset on reopening\n'
ipc call pickertest clickControl clearClipboardHistory | jq -e '.' >/dev/null
snapshot | jq -e '(.items | length) == 1 and .items[0].pinned and (.items[0].title|rtrimstr(" ")) == "hello world"' >/dev/null
[[ -f $test_dir/data/clipboard/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]]
ipc call pickertest deferredCopy
for ((try=0;try<60;try++)); do
    if snapshot | jq -e '(.visible | not)' >/dev/null; then break; fi
    sleep 0.025
done
snapshot | jq -e '(.visible | not)' >/dev/null
for ((try=0;try<60;try++)); do
    [[ -f $test_dir/copied ]] && break
    sleep 0.025
done
cmp "$test_dir/data/clipboard/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$test_dir/copied"
[[ ! -f $test_dir/injected ]]
printf 'PASS: Ctrl+C copies the highlighted entry rather than selected search text, closes the launcher and does not paste\n'
printf 'PASS: Ctrl+P and pin button toggle pins; Clear history retains pinned payloads; Delete explicitly removes a pinned entry\n'

printf 'first\nsecond\n' | bash "$picker" --dmenu -no-custom > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest down
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == second ]]

# Legacy provider flags remain accepted without changing search settings. An empty
# prompt is intentional and must reach QML rather than failing in Bash parsing.
check_dmenu() {
    local label=$1 expected=$2 input=$3; shift 3
    printf '%s' "$input" | bash "$picker" --dmenu "$@" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    if [[ $label == power ]]; then
        snapshot | jq -e '[.items[].title] == ["First","Second"]
            and [.items[].originalTitle] == ["<span>First</span>","<span>Second</span>"]
            and [.items[].result] == ["<span>First</span>","<span>Second</span>"]' >/dev/null
    elif [[ $label == 'literal grid' ]]; then
        snapshot | jq -e '[.items[].title] == ["<span>First</span>","<span>Second</span>"]' >/dev/null
    fi
    ipc call pickertest accept 1
    wait_client 0
    [[ $(<"$test_dir/result") == "$expected" ]]
    printf 'PASS: %s provider menu flags\n' "$label"
}
check_dmenu 'projects/screenshot' second $'first\nsecond\n' -case-smart -sort -sorting-method fzf -p ''
check_dmenu remotes second 'first|second' -sep '|' -dmenu -case-smart -p ''
check_dmenu recording second $'first\nsecond\n' -i -p ''
check_dmenu power '<span>Second</span>' '<span>First</span>|<span>Second</span>' -sep '|' -markup-rows -eh 4 -dmenu -case-smart -sort -sorting-method fzf --grid -p ''
check_dmenu 'literal grid' '<span>Second</span>' '<span>First</span>|<span>Second</span>' -sep '|' --grid -sort

power_script=${PICKER_TEST_POWER_SCRIPT:-$test_dir/src/services/launcher/providers/power.sh}
if [[ -f $power_script ]]; then
    power_home="$test_dir/power-home"
    mkdir -p "$power_home/.config"
    ln -s "$test_dir" "$power_home/.config/quickshell"
    HOME="$power_home" bash "$power_script" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open native
    snapshot | jq -e '.directory == "" and .layout == "grid" and [.items[].title] == ["Reboot","Lock","Logout","Shutdown","Bios"]
        and [.filtered[].title] == [.items[].title] and all(.items[]; (.glyph | length) == 1)' >/dev/null
    ipc call pickertest pressEscape
    wait_client 0
    [[ ! -s $test_dir/result ]]
    printf 'PASS: native Power CLI entry, original order, separate icon glyphs and cancellation without a shell request\n'
fi

printf 'one\n' | bash "$picker" --dmenu > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest query 'typed custom'
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == 'typed custom' ]]

printf 'one\n' | bash "$picker" --dmenu > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest pressEscape
wait_client 1
[[ ! -s $test_dir/result ]]

printf 'one\n' | bash "$picker" --dmenu -kb-accept-custom '' -kb-custom-1 Control+Return > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest custom 0
wait_client 10

[[ -z $(find "$test_dir/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
! rg -q 'PICKER FAIL|TypeError:|ReferenceError:|Binding loop detected|Failed to load configuration' "$test_dir/log"
ipc call pickertest quit
wait "$shell_pid"; shell_pid=""
export PICKER_TEST_PHASE=restart
# Pins remain durable even if limits are reduced below their combined size.
sed -Ei 's/readonly property int clipboardMaxTotalBytes: 24/readonly property int clipboardMaxTotalBytes: 1/' "$test_dir/src/config/Config.qml"
start
bash "$picker" --json "$test_dir/remember.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
snapshot | jq -e '.currentIndex == 2 and .filtered[.currentIndex].result == "tomato"' >/dev/null
ipc call pickertest pressEscape
wait_client 1
printf 'PASS: remembered launcher choice survives shell restart\n'
ipc call pickertest quit
wait "$shell_pid"; shell_pid=""
if [[ -n $placement_display ]]; then
    sed 's@"../../src@"src@g' "$project_root/tests/launcher/placement-smoke.qml" > "$test_dir/placement.qml"
    # Load the native PanelWindow backend but keep every surface hidden. No
    # keyboard grab, desktop clipboard monitoring or compositor dispatch occurs.
    QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$placement_display" timeout 10 qs -p "$test_dir/placement.qml" > "$test_dir/placement-log" 2>&1 \
        || { cat "$test_dir/placement-log"; exit 1; }
    rg -q 'PASS: picker placement' "$test_dir/placement-log" || { cat "$test_dir/placement-log"; exit 1; }
    ! rg -q 'PICKER FAIL|TypeError:|ReferenceError:|Binding loop detected|Failed to load configuration' "$test_dir/placement-log" \
        || { cat "$test_dir/placement-log"; exit 1; }
    printf 'PASS: hidden native picker placement keeps search height fixed across picker modes, filtering and visible prompts\n'
fi
printf 'PASS: real Bash/QML IPC, object results, multi-selection, keyboard navigation, typed input, Escape, custom exit and cleanup\n'
