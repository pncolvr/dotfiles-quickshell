#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-picker-test.XXXXXXXX)
shell_pid=""; client_pid=""
cleanup() {
    [[ -z $client_pid ]] || kill "$client_pid" 2>/dev/null || true
    [[ -z $shell_pid ]] || { kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; }
    rm -rf -- "$test_dir"
}
trap cleanup EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
mkdir -p "$test_dir/data/applications"
cat > "$test_dir/data/applications/picker-test.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Picker Test
Exec=true
Terminal=false
DESKTOP
cp -a "$project_root/src" "$test_dir/src"
sed -Ei 's/readonly property int clipboardMaxItems: [0-9]+/readonly property int clipboardMaxItems: 3/' "$test_dir/src/config/Config.qml"
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
ipc call pickertest snapshot | jq -e '.acceptLabel == "Open links" and (.canAccept | not)' >/dev/null
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
ipc call pickertest enter
ipc call pickertest snapshot | jq -e '.visible and .selected == [] and (.canAccept | not)' >/dev/null
ipc call pickertest query ''
ipc call pickertest down
ipc call pickertest toggleEntry
ipc call pickertest snapshot | jq -e '.selected == ["1"]' >/dev/null
ipc call pickertest clearSelection
ipc call pickertest snapshot | jq -e '.selected == [] and .query == ""' >/dev/null
ipc call pickertest query Beta
ipc call pickertest clickControl pickerSelectVisible | jq -e '.' >/dev/null
ipc call pickertest clickControl pickerAccept | jq -e '.' >/dev/null
wait_client 0
[[ $(<"$test_dir/result") == b ]]
printf 'PASS: mouse/keyboard selection, search typing, filtered selection toggle, clear all, explicit browser submission and no empty-selection fallback\n'

ipc call pickertest clipboardFixture
ipc call pickertest query 'delete me'
ipc call pickertest snapshot | jq -e '.filtered | length == 1' >/dev/null
ipc call pickertest deleteEntry
ipc call pickertest snapshot | jq -e '.query == "delete me" and .filtered == [] and (.items | length) == 1
    and .items[0].result.text == "hello\nworld\n"' >/dev/null
ipc call pickertest pressEscape
printf 'PASS: Delete removes the highlighted clipboard entry while preserving the focused search query and other history\n'

printf 'first\nsecond\n' | bash "$picker" --dmenu -no-custom > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
wait_open
ipc call pickertest down
ipc call pickertest enter
wait_client 0
[[ $(<"$test_dir/result") == second ]]

# These flag combinations are used by the migrated provider scripts. An empty
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

if [[ -n ${PICKER_TEST_POWER_SCRIPT:-} ]]; then
    power_home="$test_dir/power-home"
    mkdir -p "$power_home/.config"
    ln -s "$test_dir" "$power_home/.config/quickshell"
    HOME="$power_home" bash "$PICKER_TEST_POWER_SCRIPT" > "$test_dir/result" 2> "$test_dir/client-error" & client_pid=$!
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

if [[ -n ${PICKER_TEST_PROVIDER_HANDLE:-} ]]; then
    provider_dir="$test_dir/provider"
    test_home="$test_dir/home"
    mkdir -p "$provider_dir" "$test_home/.config"
    ln -s "$test_dir" "$test_home/.config/quickshell"
    cp "$PICKER_TEST_PROVIDER_HANDLE" "$provider_dir/handle.sh"
    printf 'open_url() { printf "%%s\\n" "$1" >> "${QS_PROVIDER_TEST_OUTPUT:?}"; }\n' > "$provider_dir/utils.sh"
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
start
ipc call pickertest quit
wait "$shell_pid"; shell_pid=""
printf 'PASS: real Bash/QML IPC, object results, multi-selection, keyboard navigation, typed input, Escape, custom exit and cleanup\n'
