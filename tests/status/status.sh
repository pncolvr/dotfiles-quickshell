#!/usr/bin/env bash
# Native reports and lifecycle against private synthetic databases; no desktop actions.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-status-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
export TZ=Europe/Lisbon
node "$project_root/tests/status/model.mjs"
mkdir -m700 "$fixture/runtime"
mkdir -p "$fixture/bin" "$fixture/home"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
# External effects are replaced before starting any Quickshell instance.
printf 'exit 0\n' > "$fixture/src/services/launcher/providers/wallpaper.sh"
cat > "$fixture/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cp "$fixture/bin/busctl" "$fixture/bin/hyprctl"
cat > "$fixture/bin/gdbus" <<'MOCK'
#!/usr/bin/env bash
sleep 30
MOCK
cat > "$fixture/bin/pgrep" <<'MOCK'
#!/usr/bin/env bash
[[ ${!#} == synthetic-work ]] || exit 1
printf '10 synthetic-work\n'
MOCK
cat > "$fixture/bin/lsof" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
chmod +x "$fixture/bin/"*
export HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
export PATH="$fixture/bin:$PATH" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
run() {
    output=$(STATUS_TEST_PHASE="$1" timeout -k 2 15 qs -p "$fixture" 2>&1) || { printf '%s\n' "$output"; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *"PASS: $2"* ]]
    [[ $output != *'STATUS FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop'* && $output != *'Failed to load configuration'* ]]
}
sed 's@"../../src@"src@g' "$project_root/tests/status/native.qml" > "$fixture/shell.qml"
run repository 'native status repository'
sed -i 's/workHistoryRetentionMonths: 36/workHistoryRetentionMonths: 6/' "$fixture/src/config/Config.qml"
run repository 'native status repository'
sed -i 's/workHistoryRetentionMonths: 6/workHistoryRetentionMonths: 36/' "$fixture/src/config/Config.qml"
# Repository tests deliberately use future timestamps; start the service with fresh sessions.
sqlite3 "$fixture/data/quickshell.db" 'DELETE FROM status_sessions; DELETE FROM status_writer;'
run seed 'native status seed'
sleep 0.1
run restore 'native status restore'
sed -i 's/workModeEnabled:true/workModeEnabled:false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
run disabled 'native status disabled'
sed 's@"../../src@"src@g' "$project_root/tests/status/timecard-parser.qml" > "$fixture/shell.qml"
run parser 'timecard parser'
cat > "$fixture/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
if [[ $* == *GetSession* ]]; then printf '%s\n' '{"data":["/org/freedesktop/login1/session/fixture"]}';
else printf '%s\n' '{"data":[{"Active":{"data":true},"LockedHint":{"data":false},"State":{"data":"active"}}]}'; fi
MOCK
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' '{"locked":false}'
MOCK
sed 's@"../../src@"src@g' "$project_root/tests/status/desktop-session.qml" > "$fixture/shell.qml"
run lifecycle 'desktop session snapshots'
[[ $(sqlite3 "$fixture/data/quickshell.db" 'PRAGMA integrity_check;') == ok ]]
printf 'PASS: native time tracking, persistence, retention and optional mode\n'
