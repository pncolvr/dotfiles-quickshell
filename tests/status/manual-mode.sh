#!/usr/bin/env bash
# Real buttons, preferences and detector lifecycle; offscreen with synthetic scans.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-status-manual.XXXXXXXX)
shell_pid=''
cleanup() {
    local result=$?
    if ((result != 0)); then cat "$fixture/log" >&2; fi
    if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/bin"
for command in hyprctl busctl gdbus; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/bin/$command"
    chmod +x "$fixture/bin/$command"
done
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property string language: .*/readonly property string language: "en"/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: false/workModeEnabled: true/' "$fixture/src/config/Config.qml"
printf 'exit 0\n' > "$fixture/src/services/launcher/providers/wallpaper.sh"
cat > "$fixture/src/services/status/detection.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
result=$(cat "$STATUS_MANUAL_TEST/result")
printf 'scan\n' >> "$STATUS_MANUAL_TEST/scans"
# Deliberately return a valid old result after cancellation to test late replies.
trap 'sleep 0.1; printf "%s\n" "$result"; exit 0' TERM
while [[ -e $STATUS_MANUAL_TEST/hold ]]; do sleep 0.02; done
printf '%s\n' "$result"
SH
sed 's@"../../src@"src@g' "$repo/tests/status/manual-mode.qml" > "$fixture/shell.qml"
export STATUS_MANUAL_TEST="$fixture"
export PATH="$fixture/bin:$PATH"
export XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE DISPLAY
work_result='{"matches":[{"name":"work-app","methods":["process"],"paths":[]}],"errors":[]}'
personal_result='{"matches":[],"errors":[]}'
printf '%s\n' "$work_result" > "$fixture/result"
qs -p "$fixture" > "$fixture/log" 2>&1 & shell_pid=$!
ipc() { timeout 2 qs ipc -p "$fixture" call manualModeTest "$@"; }
wait_state() {
    local expression=$1 snapshot=''
    for ((attempt=0;attempt<100;attempt++)); do
        snapshot=$(ipc state 2>/dev/null || true)
        if jq -e "$expression" <<< "$snapshot" >/dev/null 2>&1; then return; fi
        kill -0 "$shell_pid" 2>/dev/null || break
        sleep 0.02
    done
    printf 'STATUS MANUAL FAIL: %s; last state: %s\n' "$expression" "$snapshot" >&2
    return 1
}
scan_count() { wc -l < "$fixture/scans"; }
wait_state '.ready and .mode=="work" and .source=="automatic" and (.inFlight|not)'
ipc click work
wait_state '.mode=="work" and .source=="manual" and .workSelected and .tracking and .workHint=="Reset to automatic detection"'
before=$(scan_count)
ipc refresh
# Give the production debounce a chance to run: manual requests must launch nothing.
sleep 0.35
[[ $(scan_count) == "$before" ]]
ipc click personal
wait_state '.mode=="personal" and .source=="manual" and .personalSelected and .tracking'
printf '%s\n' "$personal_result" > "$fixture/result"
ipc click personal
wait_state '.mode=="personal" and .source=="automatic" and (.inFlight|not) and (.personalSelected|not)'
[[ $(scan_count) -gt $before ]]
printf 'PASS: automatic Work → manual Work → manual Personal → fresh automatic mode; manual refreshes launch no scans\n'

ipc click personal
touch "$fixture/hold"
printf '%s\n' "$work_result" > "$fixture/result"
ipc click personal
wait_state '.source=="automatic" and .inFlight'
ipc refresh
ipc click work
wait_state '.source=="manual" and .mode=="work" and (.inFlight|not) and (.pending|not)'
ipc state | jq -e '.automatic=="personal" and .matches==[] and .error=="" and .tracking' >/dev/null
before=$(scan_count)
sleep 0.35
[[ $(scan_count) == "$before" ]]
printf 'PASS: entering manual mode cancels running and queued detection, discards late results and keeps time tracking\n'

ipc click work
wait_state '.source=="automatic" and .inFlight'
ipc click personal
printf '%s\n' "$personal_result" > "$fixture/result"
ipc click personal
rm "$fixture/hold"
wait_state '.source=="automatic" and .mode=="personal" and (.inFlight|not) and .matches==[] and .error==""'
[[ $(scan_count) -gt $before ]]
printf 'PASS: rapid manual/automatic handoff discards the cancelled scan and runs fresh detection\n'
if rg -q 'TypeError:|ReferenceError:|Binding loop|WARN scene|Failed to load configuration' "$fixture/log"; then exit 1; fi
