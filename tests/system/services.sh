#!/usr/bin/env bash
# Service regressions use private storage and mocked desktop commands.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-services-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
fixture_directory() {
    mkdir -p "$1/data" "$1/cache"
    mkdir -m 700 "$1/runtime"
    tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$1" -xf -
}
override_config() {
    local directory=$1 name=$2 value=$3 line count=0
    local pattern="^([[:space:]]*readonly property (var|int|bool) $name: )"
    while IFS= read -r line; do
        if [[ $line =~ $pattern ]]; then
            printf '%s%s\n' "${BASH_REMATCH[1]}" "$value"
            count=$((count + 1))
        else printf '%s\n' "$line"; fi
    done < "$directory/src/config/Config.qml" > "$directory/config.next"
    [[ $count == 1 ]] || { printf 'Missing configuration property: %s\n' "$name" >&2; return 1; }
    mv "$directory/config.next" "$directory/src/config/Config.qml"
}
run_qml() {
    local directory=$1 fixture=$2 phase=${3:-} output line
    sed 's@"../../src@"src@g;s@"../launcher"@"."@g' "$project_root/$fixture" > "$directory/shell.qml"
    output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$directory/runtime" \
        XDG_DATA_HOME="$directory/data" XDG_CACHE_HOME="$directory/cache" SERVICES_TEST_PHASE="$phase" \
        timeout 10 qs -p "$directory" 2>&1) || { printf '%s\n' "$output" >&2; return 1; }
    if [[ $output != *'PASS:'* || $output == *'SERVICES FAIL:'* || $output == *'Failed to load configuration'* \
        || $output == *'TypeError:'* || $output == *'ReferenceError:'* || $output == *'Binding loop detected'* ]]; then
        printf '%s\n' "$output" >&2; return 1
    fi
    while IFS= read -r line; do [[ $line != *'PASS:'* ]] || printf '%s\n' "$line"; done <<< "$output"
}

clipboard="$test_dir/clipboard"
fixture_directory "$clipboard"
override_config "$clipboard" clipboardMonitorEnabled false
override_config "$clipboard" clipboardCommand '["bash", Quickshell.shellPath("clipboard-helper.sh")]'
cat > "$clipboard/clipboard-helper.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
directory=$(dirname "$0")
printf '%s\n' "$1" >> "$directory/actions"
if [[ ${SERVICES_TEST_PHASE:-} == prune-failure && ! -f $directory/failed-once ]]; then
    touch "$directory/failed-once"
    exit 1
fi
exec bash "$directory/src/services/clipboard/clipboard.sh" "$@"
MOCK
payload="$clipboard/data/clipboard/$(printf 'a%.0s' {1..64})"
mkdir -p "${payload%/*}"
printf 'retained payload' > "$payload"
sqlite3 "$clipboard/data/quickshell.db" 'PRAGMA user_version=999;'
run_qml "$clipboard" tests/clipboard/storage-smoke.qml database-failure
[[ $(cat "$payload") == 'retained payload' && ! -e $clipboard/actions ]]
sqlite3 "$clipboard/data/quickshell.db" 'PRAGMA user_version=0;'
run_qml "$clipboard" tests/clipboard/storage-smoke.qml prune-failure
[[ ! -e $payload && $(cat "$clipboard/actions") == $'prune\nprune' ]]
rm "$clipboard/actions"
run_qml "$clipboard" tests/clipboard/storage-smoke.qml recovery
[[ $(cat "$clipboard/actions") == prune ]]

network="$test_dir/network"
fixture_directory "$network"
override_config "$network" networkCheckCommand '["printf", "1\n"]'
override_config "$network" networkVpnCommand '["printf", "%s\n", "Work\\:VPN\\\\Office:vpn:activated"]'
run_qml "$network" tests/system/network-smoke.qml

updates="$test_dir/updates"
fixture_directory "$updates"
override_config "$updates" networkCheckCommand '["printf", "0\n"]'
override_config "$updates" updatesCheckCommand '["bash", Quickshell.shellPath("update-snapshot.sh")]'
override_config "$updates" updatesRefreshCommand '["true"]'
cat > "$updates/update-snapshot.sh" <<'MOCK'
#!/usr/bin/env bash
counter_file="$(dirname "$0")/counter"
count=$(cat "$counter_file" 2>/dev/null || printf 0)
count=$((count + 1))
printf '%s' "$count" > "$counter_file"
case $count in
    1) printf 'core x86_64 linux 1 2\nextra x86_64 example 1 2\n' ;;
    2) printf 'extra x86_64 partial 1 2\n'; exit 1 ;;
    3) printf 'extra x86_64 partial 1 2\nbroken row\n' ;;
    *) exit 0 ;;
esac
MOCK
run_qml "$updates" tests/system/updates-smoke.qml

updates_refresh="$test_dir/updates-refresh"
fixture_directory "$updates_refresh"
cat > "$updates_refresh/src/services/system/NetworkService.qml" <<'QML'
pragma Singleton
import QtQml
QtObject { property bool online: true }
QML
sed -i 's/readonly property string language:/property string language:/' "$updates_refresh/src/config/Config.qml"
override_config "$updates_refresh" updatesScheduleDelay 600
override_config "$updates_refresh" updatesCheckCommand '["cat", Quickshell.shellPath("snapshot")]'
override_config "$updates_refresh" updatesRefreshCommand '["bash", Quickshell.shellPath("refresh.sh")]'
: > "$updates_refresh/snapshot"
: > "$updates_refresh/runs"
cat > "$updates_refresh/refresh.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
directory=$(dirname "$0")
printf 'check\n' >> "$directory/runs"
count=$(wc -l < "$directory/runs")
sleep 0.15
case $count in
    1|4) : > "$directory/snapshot" ;;
    3) exit 1 ;;
    *) printf 'core x86_64 linux 1 2\n' > "$directory/snapshot" ;;
esac
MOCK
run_qml "$updates_refresh" tests/system/updates-refresh.qml
[[ $(wc -l < "$updates_refresh/runs") -eq 5 ]]

updates_panel="$test_dir/updates-panel"
fixture_directory "$updates_panel"
override_config "$updates_panel" networkCheckCommand '["printf", "0\n"]'
override_config "$updates_panel" updatesCheckCommand '["printf", ""]'
override_config "$updates_panel" updatesRefreshCommand '["true"]'
sed -i 's/readonly property var updatesCheckCommand:/property var updatesCheckCommand:/;s/readonly property string language:.*/readonly property string language: "en"/' "$updates_panel/src/config/Config.qml"
cp "$project_root/tests/launcher/NativeFocusDriver.qml" "$updates_panel/"
run_qml "$updates_panel" tests/system/updates-panel.qml

# Prime an existing engine before introducing the new section type and tooltip.
sed -i 's/^    property var updatesCheckCommand:/    readonly property var updatesCheckCommand:/' "$updates_panel/src/config/Config.qml"
override_config "$updates_panel" updatesCheckCommand '["printf", "core x86_64 linux 1 2\n"]'
rm "$updates_panel/src/modules/updates/UpdateSection.qml"
cat > "$updates_panel/src/modules/updates/UpdatesTooltip.qml" <<'QML'
import QtQuick
import "../../ui" as UI
Column { width: 320; UI.ColumnText { text: "Original updates tooltip" } }
QML
sed 's@"../../src@"src@g' "$project_root/tests/system/updates-reload.qml" > "$updates_panel/shell.qml"
(
    export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1
    export XDG_RUNTIME_DIR="$updates_panel/runtime" XDG_DATA_HOME="$updates_panel/data" XDG_CACHE_HOME="$updates_panel/cache"
    unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
    qs -p "$updates_panel" > "$updates_panel/reload.log" 2>&1 &
    probe_pid=$!
    cleanup_reload() {
        local result=$?
        if ((result != 0)); then cat "$updates_panel/reload.log" >&2; fi
        kill "$probe_pid" 2>/dev/null || true
        wait "$probe_pid" 2>/dev/null || true
    }
    trap cleanup_reload EXIT
    ipc_reload() { timeout 2 qs ipc -p "$updates_panel" call updatesReloadTest "$@"; }
    wait_reload() {
        local expression=$1 attempt
        for ((attempt=0; attempt<80; attempt++)); do
            if snapshot=$(ipc_reload state 2>/dev/null) && jq -e "$expression" <<< "$snapshot" >/dev/null; then return; fi
            kill -0 "$probe_pid" 2>/dev/null || break
            sleep 0.05
        done
        printf 'SERVICES FAIL: updates reload %s; last state: %s\n' "$expression" "${snapshot:-unavailable}" >&2
        return 1
    }
    wait_reload '.count==1 and (.search|not)'
    generation=$(jq -r .generation <<< "$snapshot")
    cp "$project_root/src/modules/updates/UpdateSection.qml" "$updates_panel/src/modules/updates/"
    cp "$project_root/src/modules/updates/UpdatesTooltip.qml" "$updates_panel/src/modules/updates/"
    ipc_reload reload >/dev/null
    wait_reload ".generation!=\"$generation\" and .search and .priorityCount==\"1\""
    generation=$(jq -r .generation <<< "$snapshot")
    ipc_reload reload >/dev/null
    wait_reload ".generation!=\"$generation\" and .search and .priorityCount==\"1\""
    ! rg -q 'Failed to load configuration|TypeError:|ReferenceError:|Binding loop' "$updates_panel/reload.log"
    ipc_reload quit >/dev/null
    wait "$probe_pid"
    trap - EXIT
    printf 'PASS: existing-engine updates upgrade and repeated reload preserve search and section counts\n'
)
