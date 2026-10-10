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
chmod +x "$test_dir/bin/wl-copy" "$test_dir/bin/ydotool"
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
sed -Ei 's/readonly property int clipboardMaxItems: [0-9]+/readonly property int clipboardMaxItems: 3/' "$test_dir/src/config/Config.qml"
sed -Ei 's/readonly property int clipboardMaxTotalBytes: [0-9]+/readonly property int clipboardMaxTotalBytes: 24/' "$test_dir/src/config/Config.qml"
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$test_dir/src/config/Config.qml"
sed -i 's/readonly property bool pickerShowPrompt: false/readonly property bool pickerShowPrompt: true/' "$test_dir/src/config/Config.qml"
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
    qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
    for ((try=0;try<80;try++)); do
        if rg -q 'PASS: picker' "$test_dir/log"; then return; fi
        if ! kill -0 "$shell_pid" 2>/dev/null; then cat "$test_dir/log"; exit 1; fi
        sleep 0.05
    done
    cat "$test_dir/log"; exit 1
}
wait_open() {
    for ((try=0;try<60;try++)); do
        if ipc call pickertest snapshot | jq -e '.visible and (.directory|length > 0)' >/dev/null; then return; fi
        sleep 0.025
    done
    cat "$test_dir/log"; exit 1
}
wait_client() {
    client_exit=0; wait "$client_pid" || client_exit=$?; client_pid=""
    [[ $client_exit == "$1" ]] || { cat "$test_dir/client-error"; printf 'Unexpected client exit: %s\n' "$client_exit"; exit 1; }
}
start
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

# External search flags must not override the shared Config.qml settings.
printf '%s\n' '{"fuzzy":false,"smartCase":false,"allowTyped":false,"items":[{"title":"Banana","result":"fruit"},{"title":"Potato","result":"vegetable"}]}' > "$test_dir/search.json"
bash "$picker" --json "$test_dir/search.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest query bna
ipc call pickertest snapshot | jq -e '.filtered | length == 1 and .[0].title == "Banana"' >/dev/null
ipc call pickertest query BNA
ipc call pickertest snapshot | jq -e '.filtered | length == 1 and .[0].title == "Banana"' >/dev/null
ipc call pickertest query bNa
ipc call pickertest snapshot | jq -e '.filtered | length == 0' >/dev/null
ipc call pickertest query bna
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == fruit ]]

printf 'Tomato\nPotato\n' | bash "$picker" --dmenu -i -sorting-method normal -no-custom > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest query TMT
ipc call pickertest snapshot | jq -e '.filtered | length == 1 and .[0].title == "Tomato"' >/dev/null
ipc call pickertest query tMt
ipc call pickertest snapshot | jq -e '.filtered | length == 0' >/dev/null
ipc call pickertest query tmt
ipc call pickertest snapshot | jq -e '.filtered | length == 1 and .[0].title == "Tomato"' >/dev/null
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == Tomato ]]
printf 'PASS: JSON and dmenu use shared fuzzy search and cannot override case or matching settings\n'

# Restore accepted results by identity, with independent history for each step.
printf '%s\n' '{"selectionKey":"test.menu","allowTyped":false,"items":[{"title":"Banana","result":"banana"},{"title":"Potato","result":"potato"},{"title":"Tomato","result":"tomato"}]}' > "$test_dir/remember.json"
bash "$picker" --json "$test_dir/remember.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest snapshot | jq -e '.currentIndex == 0' >/dev/null
ipc call pickertest accept 2
wait_client 0
bash "$picker" --json "$test_dir/remember.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest snapshot | jq -e '.currentIndex == 2 and .filtered[.currentIndex].result == "tomato" and .query == ""' >/dev/null
ipc call pickertest pressEscape
wait_client 1
jq '.items = [.items[1], .items[2], .items[0]]' "$test_dir/remember.json" > "$test_dir/reordered.json"
bash "$picker" --json "$test_dir/reordered.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest snapshot | jq -e '.currentIndex == 1 and .filtered[.currentIndex].result == "tomato"' >/dev/null
ipc call pickertest pressEscape
wait_client 1

for project in banana potato; do
    printf 'Open folder\nBanana\nTomato\n' | bash "$picker" --dmenu -no-custom --selection-key "projects.workspaces:$project" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    ipc call pickertest snapshot | jq -e '.currentIndex == 0 and .items[0].title == "Open folder"' >/dev/null
    if [[ $project == banana ]]; then ipc call pickertest accept 2; else ipc call pickertest enter; fi
    wait_client 0
done
printf 'Open folder\nBanana\nTomato\n' | bash "$picker" --dmenu -no-custom --selection-key projects.workspaces:banana > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest snapshot | jq -e '.currentIndex == 2 and .items[0].title == "Open folder"' >/dev/null
ipc call pickertest pressEscape
wait_client 1
jq '.items |= map(select(.result != "tomato"))' "$test_dir/remember.json" > "$test_dir/missing.json"
bash "$picker" --json "$test_dir/missing.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest snapshot | jq -e '.currentIndex == 0' >/dev/null
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
ipc call pickertest snapshot | jq -e '.acceptLabel == "Open links" and .canAccept and .selected == []' >/dev/null
ipc call pickertest pasteFixture false | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.query == "Beta" and .selected == []' >/dev/null
ipc call pickertest query 'Prefix '
ipc call pickertest pasteFixture false | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.query == "Prefix Beta" and .selected == []' >/dev/null
ipc call pickertest pasteFixture true | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.query == "Beta" and .selected == []' >/dev/null
printf 'PASS: native Ctrl+V inserts clipboard text at the cursor and replaces selected text\n'
ipc call pickertest query Alpha
ipc call pickertest clickControl pickerSelectVisible | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.selected == ["0"]' >/dev/null
ipc call pickertest toggleEntry
ipc call pickertest snapshot | jq -e '.selected == [] and .query == "Alpha"' >/dev/null
ipc call pickertest toggleEntry
ipc call pickertest typeSpace
ipc call pickertest snapshot | jq -e '.selected == ["0"] and .query == "Alpha "' >/dev/null
ipc call pickertest query Beta
ipc call pickertest toggleVisible
ipc call pickertest snapshot | jq -e '.selected == ["0","1"]' >/dev/null
ipc call pickertest toggleVisible
ipc call pickertest snapshot | jq -e '.selected == [] and .canAccept' >/dev/null
ipc call pickertest query 'no matching link'
ipc call pickertest enter
ipc call pickertest snapshot | jq -e '.visible and .selected == [] and (.canAccept | not)' >/dev/null
ipc call pickertest query ''
ipc call pickertest down
ipc call pickertest toggleEntry
ipc call pickertest snapshot | jq -e '.selected == ["1"] and .currentIndex == 2' >/dev/null
ipc call pickertest clearSelection
ipc call pickertest snapshot | jq -e '.selected == [] and .query == ""' >/dev/null
ipc call pickertest query Beta
ipc call pickertest clickControl pickerSelectVisible | jq -e '.' >/dev/null
ipc call pickertest clickControl pickerAccept | jq -e '.' >/dev/null
wait_client 0
[[ $(<"$test_dir/result") == b ]]
for activation in keyboard button; do
    bash "$picker" --json "$test_dir/links.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    if [[ $activation == keyboard ]]; then ipc call pickertest down; else ipc call pickertest query Beta; fi
    ipc call pickertest snapshot | jq -e '.selected == [] and .canAccept and .filtered[.currentIndex].result == "b"' >/dev/null
    if [[ $activation == keyboard ]]; then ipc call pickertest enter; else ipc call pickertest clickControl pickerAccept | jq -e '.' >/dev/null; fi
    wait_client 0
    [[ $(<"$test_dir/result") == b ]]
done
printf 'PASS: mouse/keyboard selection, search typing, filtered selection toggle, clear all, selected-entry submission and highlighted-row fallback with Enter/button\n'

ipc call pickertest clipboardFixture
ipc call pickertest query 'delete me'
ipc call pickertest snapshot | jq -e '.filtered | length == 1' >/dev/null
ipc call pickertest togglePin
ipc call pickertest snapshot | jq -e '.query == "delete me" and .filtered[0].pinned' >/dev/null
ipc call pickertest deleteEntry
ipc call pickertest snapshot | jq -e '.query == "delete me" and .filtered == [] and (.items | length) == 1
    and .items[0].result.text == "hello\nworld\n"' >/dev/null
ipc call pickertest query ''
ipc call pickertest togglePin
ipc call pickertest snapshot | jq -e '.query == "" and .items[0].pinned and .currentIndex == 0' >/dev/null
ipc call pickertest clickControl pinClipboardEntry | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '(.items[0].pinned | not)' >/dev/null
ipc call pickertest togglePin
ipc call pickertest clipboardFixture
ipc call pickertest togglePinnedOnly
ipc call pickertest snapshot | jq -e '.itemCriteria.pinned and (.filtered | length) == 1 and .filtered[0].pinned and (.items | length) == 2' >/dev/null
ipc call pickertest query 'delete me'
ipc call pickertest snapshot | jq -e '.filtered == [] and (.canAccept | not)' >/dev/null
ipc call pickertest togglePinnedOnly
ipc call pickertest snapshot | jq -e '.itemCriteria == {} and .query == "delete me" and (.filtered | length) == 1 and (.filtered[0].pinned | not)' >/dev/null
ipc call pickertest query hello
ipc call pickertest togglePinnedOnly
ipc call pickertest togglePin
ipc call pickertest snapshot | jq -e '.itemCriteria.pinned and .query == "hello" and .filtered == [] and (.canAccept | not)' >/dev/null
ipc call pickertest togglePinnedOnly
ipc call pickertest togglePin
ipc call pickertest query ''
ipc call pickertest clickControl clipboardPinnedOnly | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.itemCriteria.pinned and (.filtered | length) == 1 and .filtered[0].pinned' >/dev/null
ipc call pickertest clickControl clipboardPinnedOnly | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '.itemCriteria == {} and (.filtered | length) == 2' >/dev/null
ipc call pickertest togglePinnedOnly
ipc call pickertest clipboardFixture
ipc call pickertest snapshot | jq -e '.itemCriteria == {} and (.filtered | length) == 2' >/dev/null
printf 'PASS: pinned-only keyboard/button toggle, combined search, unpinning while filtered, empty results and reset on reopening\n'
ipc call pickertest clickControl clearClipboardHistory | jq -e '.' >/dev/null
ipc call pickertest snapshot | jq -e '(.items | length) == 1 and .items[0].pinned and .items[0].result.text == "hello\nworld\n"' >/dev/null
[[ -f $test_dir/data/clipboard/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]]
ipc call pickertest query hello
ipc call pickertest copyEntry
ipc call pickertest snapshot | jq -e '(.visible | not)' >/dev/null
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
    ipc call pickertest accept 1
    wait_client 0
    [[ $(<"$test_dir/result") == "$expected" ]]
    printf 'PASS: %s provider menu flags\n' "$label"
}
check_dmenu 'projects/screenshot' second $'first\nsecond\n' -case-smart -sort -sorting-method fzf -p ''
check_dmenu remotes second 'first|second' -sep '|' -dmenu -case-smart -p ''
check_dmenu recording second $'first\nsecond\n' -i -p ''
check_dmenu power '<span>Second</span>' '<span>First</span>|<span>Second</span>' -sep '|' -markup-rows -eh 4 -dmenu -case-smart -sort -sorting-method fzf --grid -p ''

power_script=${PICKER_TEST_POWER_SCRIPT:-$test_dir/src/services/launcher/providers/power.sh}
if [[ -f $power_script ]]; then
    power_home="$test_dir/power-home"
    mkdir -p "$power_home/.config"
    ln -s "$test_dir" "$power_home/.config/quickshell"
    HOME="$power_home" bash "$power_script" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    ipc call pickertest snapshot | jq -e '.layout == "grid" and [.items[].title] == ["Reboot","Lock","Logout","Shutdown","Bios"]
        and [.filtered[].title] == [.items[].title] and all(.items[]; (.glyph | length) == 1)' >/dev/null
    ipc call pickertest pressEscape
    wait_client 0
    [[ ! -s $test_dir/result ]]
    printf 'PASS: actual power-provider order, separate icon glyphs and cancellation without executing an action\n'
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

provider_handle=${PICKER_TEST_PROVIDER_HANDLE:-$test_dir/src/services/launcher/providers/_common/handle.sh}
if [[ -f $provider_handle ]]; then
    provider_dir="$test_dir/provider"
    test_home="$test_dir/home"
    mkdir -p "$provider_dir" "$test_home/.config"
    ln -s "$test_dir" "$test_home/.config/quickshell"
    cp "$provider_handle" "$provider_dir/handle.sh"
    printf 'PICKER_LAUNCHER=%q\n' "$picker" > "$provider_dir/utils.sh"
    printf 'open_url() { printf "%%s\\n" "$1" >> "${QS_PROVIDER_TEST_OUTPUT:?}"; }\n' >> "$provider_dir/utils.sh"
    jq '. + {action:"output"}' "$test_dir/options.json" > "$test_dir/provider.json"
    HOME="$test_home" bash "$provider_dir/handle.sh" "$test_dir/provider.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    ipc call pickertest accept 1
    wait_client 0
    [[ $(<"$test_dir/result") == '{"path":"second"}' ]]
    jq '. + {action:"default"}' "$test_dir/options.json" > "$test_dir/provider.json"
    HOME="$test_home" QS_PROVIDER_TEST_OUTPUT="$test_dir/browser" bash "$provider_dir/handle.sh" "$test_dir/provider.json" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
    wait_open
    ipc call pickertest accept 0
    wait_client 0
    [[ $(<"$test_dir/browser") == first ]]
    printf 'PASS: existing provider JSON output and browser actions through the migrated shared handler\n'
fi

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
ipc call pickertest snapshot | jq -e '.currentIndex == 2 and .filtered[.currentIndex].result == "tomato"' >/dev/null
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
