#!/usr/bin/env bash
# Run explicit suite entry points, not fixture helpers or mock executables.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
native=false
benchmarks=false
list=false
for option in "$@"; do
    case "$option" in
        --native) native=true ;;
        --benchmarks) benchmarks=true ;;
        --list) list=true ;;
        --help|-h)
            printf 'Usage: bash tests/run.sh [--native] [--benchmarks] [--list]\n'
            printf 'Default: isolated suites. --native adds desktop checks; leave keyboard/mouse idle.\n'
            printf 'Logs are retained under /tmp. TEST_TIMEOUT sets the per-suite limit (default 180 seconds).\n'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$option" >&2; exit 2 ;;
    esac
done
if $native && ! $list && [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'Native suites require a running Wayland session.\n' >&2
    exit 2
fi
if ! $list && [[ ${QS_TEST_RUNNER_BUS:-0} != 1 ]]; then
    if $native; then
        # Test services use a private bus; status notifications belong on the desktop.
        exec dbus-run-session -- env QS_TEST_RUNNER_BUS=1 \
            QS_TEST_DESKTOP_BUS="${DBUS_SESSION_BUS_ADDRESS:-}" bash "$0" "$@"
    fi
    # Activation helpers inherit the bus daemon's environment, not each client's.
    exec env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
        dbus-run-session -- env QS_TEST_RUNNER_BUS=1 bash "$0" "$@"
fi
cd -- "$repo"
limit=${TEST_TIMEOUT:-180}
[[ $limit =~ ^[1-9][0-9]*$ ]] || { printf 'TEST_TIMEOUT must be a positive number of seconds.\n' >&2; exit 2; }
passed=0
failed=0
total=0
native_running=false
native_notification_id=''
desktop_bus=${QS_TEST_DESKTOP_BUS:-}

notify_native() {
    [[ -n $desktop_bus ]] && command -v notify-send >/dev/null 2>&1 || return 1
    timeout 5 env DBUS_SESSION_BUS_ADDRESS="$desktop_bus" notify-send \
        --app-name='Quickshell tests' "$@"
}
finish_native() {
    $native_running || return 0
    native_running=false
    local status=${1:-0} summary='Native tests finished' body
    if ((status != 0)); then summary='Native tests stopped'; fi
    body="You can use the keyboard and mouse now. Results so far: $passed passed, $failed failed. Logs: $logs"
    if [[ $native_notification_id =~ ^[1-9][0-9]*$ ]]; then
        notify_native --replace-id="$native_notification_id" --urgency=normal \
            --expire-time=8000 "$summary" "$body" >/dev/null 2>&1 || true
    fi
    printf '%s. You can use the keyboard and mouse now.\n' "$summary"
}
if ! $list; then
    logs=$(mktemp -d /tmp/quickshell-tests.XXXXXXXX)
    printf 'Logs: %s\n' "$logs"
    printf 'status\tseconds\tsuite\tlog\n' > "$logs/results.tsv"
    trap 'printf "Interrupted; logs: %s\n" "$logs" >&2; exit 130' INT
    trap 'printf "Stopped; logs: %s\n" "$logs" >&2; exit 143' TERM
    trap 'finish_native "$?"' EXIT
fi
run() {
    local mode=$1 name=$2
    shift 2
    if $list; then
        printf '%s\t%s\t' "$mode" "$name"
        printf '%q ' "$@"
        printf '\n'
        return
    fi
    total=$((total + 1))
    local log="$logs/$(printf '%03d' "$total")-${name//\//-}.log"
    local started=$SECONDS status=0
    printf 'RUN  %s\n' "$name"
    if [[ $mode == isolated ]]; then
        env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
            QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 \
            CLIPBOARD_NATIVE=0 PREVIEW_NATIVE=0 SCREENSHOT_TEST_NATIVE=0 \
            WALL_TEST_NATIVE=0 WALLPAPER_TEST_NATIVE=0 RECORD_SETUP_NATIVE=0 \
            NOTIFICATION_TEST_WAYLAND=0 \
            timeout --kill-after=10 "$limit" "$@" > "$log" 2>&1 || status=$?
    else
        timeout --kill-after=10 "$limit" "$@" > "$log" 2>&1 || status=$?
    fi
    local elapsed=$((SECONDS - started)) result=PASS
    if ((status == 0)); then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        result=FAIL
    fi
    printf '%s %s (%ss; exit %s)\n' "$result" "$name" "$elapsed" "$status"
    printf '%s\t%s\t%s\t%s\n' "$result" "$elapsed" "$name" "$log" >> "$logs/results.tsv"
}

run isolated qml/lint bash tests/qml/lint.sh
run isolated qml/singletons bash tests/qml/singletons.sh
run isolated qml/selection bash tests/qml/selection.sh
run isolated qml/button-focus bash tests/qml/button-focus.sh
run isolated qml/batched-model bash tests/qml/batched-model.sh
run isolated qml/alerts bash tests/qml/alerts.sh
run isolated i18n bash tests/i18n/run.sh
run isolated audio/controls bash tests/audio/audio.sh
run isolated audio/media bash tests/audio/media.sh
run isolated audio/spectrum bash tests/audio/spectrum.sh
run isolated audio/visualizer bash tests/audio/media-visualizer.sh
run isolated audio/screencast bash tests/audio/screencast.sh
run isolated clipboard/helpers bash tests/clipboard/clipboard.sh
run isolated clipboard/index bash tests/clipboard/fts/run.sh
run isolated clipboard/contention bash tests/clipboard/fts/contention.sh
run isolated clipboard/ui bash tests/clipboard/fts/ui.sh
run isolated clipboard/ui-narrow env CLIPBOARD_NARROW=1 bash tests/clipboard/fts/ui.sh
run isolated clipboard/ui-zero-motion env CLIPBOARD_ZERO_MOTION=1 bash tests/clipboard/fts/ui.sh
run isolated clipboard/previews bash tests/clipboard/fts/previews.sh
run isolated images/crops bash tests/images/crops.sh
run isolated files/recent bash tests/files/recent-files.sh
run isolated directories bash tests/directories/directories.sh
run isolated hyprland/capture-sync bash tests/hyprland/capture-sync.sh
run isolated launcher/bridge bash tests/launcher/launcher.sh
run isolated launcher/providers bash tests/launcher/providers.sh
run isolated launcher/provider-config bash tests/launcher/provider-config.sh
run isolated launcher/bookmarks bash tests/launcher/bookmarks.sh
run isolated launcher/clipboard-search bash tests/launcher/clipboard-search.sh
run isolated launcher/clipboard-handoff bash tests/launcher/clipboard-handoff.sh
run isolated launcher/encode-qrcode bash tests/launcher/encode-qrcode.sh
run isolated launcher/expose bash tests/launcher/expose.sh
run isolated launcher/floating-preview bash tests/launcher/floating-preview.sh
run isolated launcher/manage-layout bash tests/launcher/manage-layout.sh
run isolated launcher/opening-policy bash tests/launcher/opening-policy.sh
run isolated launcher/power bash tests/launcher/power.sh
run isolated launcher/screenshot bash tests/launcher/screenshot.sh
run isolated launcher/capture-close-model node tests/launcher/capture-close-timing.mjs
run isolated launcher/wallpaper bash tests/launcher/wallpaper.sh
run isolated launcher/window-switcher bash tests/launcher/window-switcher.sh
run isolated projects/scan bash tests/projects/scan.sh
run isolated projects/model node --test tests/projects/launchers.test.mjs
run isolated projects/launchers bash tests/projects/launchers.sh
run isolated projects/sources bash tests/projects/projects.sh
run isolated projects/grouping bash tests/projects/grouping.sh
run isolated projects/manage bash tests/projects/manage.sh
run isolated webapps/model node tests/webapps/model.mjs
run isolated webapps/manage bash tests/webapps/manage.sh
run isolated webapps/browser bash tests/webapps/qutebrowser.sh
run isolated n8n/model node tests/n8n/model.mjs
run isolated n8n/manage bash tests/n8n/manage.sh
run isolated remotes/model node tests/remotes/model.mjs
run isolated remotes/worker bash tests/remotes/worker.sh
run isolated remotes/ssh bash tests/remotes/ssh.sh
run isolated remotes/manage bash tests/remotes/manage.sh
run isolated notifications/protocol bash tests/notifications/notifications.sh
run isolated notifications/animations bash tests/notifications/animations.sh
run isolated security/totp bash tests/security/totp.sh --qml-smoke
run isolated security/optional-modules bash tests/security/optional-modules.sh
run isolated security/rbw bash tests/security/rbw/run.sh
run isolated security/vault-manager bash tests/security/rbw-manager/run.sh
run isolated status/lifecycle bash tests/status/status.sh
run isolated status/detection bash tests/status/detection.sh
run isolated status/detection-ui bash tests/status/detection-ui.sh
run isolated status/reload bash tests/status/reload.sh
run isolated storage/twitch bash tests/storage/storage.sh --ipc
run isolated storage/twitch-fallback bash tests/storage/twitch-fallback.sh
run isolated storage/browser-sessions bash tests/storage/qutebrowser-channels.sh
run isolated storage/backup bash tests/storage/backup.sh
run isolated storage/backup-ui bash tests/storage/backup-ui.sh
run isolated system/services bash tests/system/services.sh
run isolated system/update-cache bash tests/system/update-cache.sh
run isolated system/batteries bash tests/system/batteries.sh
run isolated system/stats bash tests/system/stats.sh
run isolated system/stats-optional bash tests/system/stats-optional.sh
run isolated system/optional-integrations bash tests/system/optional-integrations.sh
run isolated time/calendar bash tests/time/calendar.sh
run isolated time/timers bash tests/time/timers.sh
run isolated recording/setup bash tests/recording/setup.sh
run isolated recording/worker bash tests/recording/worker.sh
run isolated ui/folder-dialog bash tests/ui/folder-dialog.sh
run isolated ui/keybinds bash tests/ui/keybinds.sh
run isolated ui/module-pins bash tests/ui/module-pins.sh
run isolated ui/panel-motion bash tests/ui/panel-motion.sh
run isolated ui/reload bash tests/ui/reload-warnings.sh
run isolated ui/rows bash tests/ui/rows.sh
run isolated ui/hints bash tests/ui/shortcut-hints.sh
run isolated ui/theme bash tests/ui/theme.sh
run isolated ui/hover bash tests/ui/tooltip-hover.sh
run isolated ui/search python3 tests/ui/tooltip-search.py

if $benchmarks; then
    run isolated benchmark/clipboard bash tests/clipboard/fts/benchmark.sh
    run isolated benchmark/projects bash tests/projects/grouping-benchmark.sh
fi
if $native; then
    if ! $list; then
        native_running=true
        printf '\nNative tests will start in the next 60 seconds.\nLeave the keyboard and mouse idle until the completion notice.\n'
        native_notification_id=$(notify_native --print-id --urgency=critical --expire-time=0 \
            'Native tests starting' $'Tests will start in the next 60 seconds.\nLeave the keyboard and mouse idle until the completion notice.') \
            || printf 'Desktop notification unavailable; follow the status in this terminal.\n' >&2
        sleep 60
        printf 'Native tests are now running.\nLeave the keyboard and mouse idle until the completion notice.\n'
        notification_options=()
        if [[ $native_notification_id =~ ^[1-9][0-9]*$ ]]; then
            notification_options+=(--replace-id="$native_notification_id")
        fi
        native_notification_id=$(notify_native --print-id "${notification_options[@]}" --urgency=critical --expire-time=0 \
            'Native tests running' $'Tests are now running.\nLeave the keyboard and mouse idle until the completion notice.') \
            || printf 'Desktop notification unavailable; follow the status in this terminal.\n' >&2
    fi
    # Explicit opt-in: these checks can take focus, move the pointer or use GPU capture.
    run native audio/imports bash tests/audio/audio.sh --native-imports
    run native audio/fullscreen bash tests/audio/media-fullscreen.sh
    run native audio/visualizer bash tests/audio/media-visualizer.sh --native
    run native audio/visualizer-gpu bash tests/audio/media-visualizer.sh --gpu
    run native audio/screencast bash tests/audio/screencast.sh --native
    run native clipboard/ui env CLIPBOARD_NATIVE=1 bash tests/clipboard/fts/ui.sh
    run native clipboard/previews env PREVIEW_NATIVE=1 bash tests/clipboard/fts/previews.sh
    run native files/folder bash tests/files/recent-folder-native.sh
    run native images/crops bash tests/images/crops.sh --wayland
    run native launcher/bridge bash tests/launcher/launcher.sh
    run native launcher/expose bash tests/launcher/expose.sh
    run native launcher/shortcuts bash tests/launcher/global-shortcuts.sh
    run native launcher/pointer bash tests/launcher/native-pointer.sh
    run native launcher/focus bash tests/launcher/opening-focus.sh
    run native launcher/wayland bash tests/launcher/wayland.sh
    run native launcher/screenshot env SCREENSHOT_TEST_NATIVE=1 bash tests/launcher/screenshot.sh
    run native launcher/wallpaper env WALLPAPER_TEST_NATIVE=1 bash tests/launcher/wallpaper.sh
    run native notifications/protocol bash tests/notifications/notifications.sh --wayland
    run native notifications/animations bash tests/notifications/animations.sh --wayland
    run native notifications/startup bash tests/notifications/startup.sh
    run native projects/choices bash tests/projects/choices-focus.sh
    run native projects/folder bash tests/projects/folder-picker.sh
    run native qml/pulse bash tests/qml/pulse.sh
    run native qml/selection bash tests/qml/selection.sh --native
    run native qml/selection-hover bash tests/qml/selection-hover.sh
    run native security/totp bash tests/security/totp.sh --qml-smoke --native-imports
    run native security/rbw bash tests/security/rbw/native.sh
    run native security/vault-manager bash tests/security/rbw-manager/native.sh
    run native system/batteries bash tests/system/batteries.sh --native-imports
    run native recording/setup env RECORD_SETUP_NATIVE=1 bash tests/recording/setup.sh
    run native ui/panel-host bash tests/ui/panel-host.sh
    run native ui/panel-input bash tests/ui/panel-input.sh
    run native ui/panel-shadow bash tests/ui/panel-shadow.sh
    run native ui/twitch bash tests/ui/twitch-panel.sh
    run native ui/unlock bash tests/ui/unlock-focus.sh
    finish_native
fi
if ! $list; then
    printf '\nSuites: %s passed, %s failed, %s total.\nLogs: %s\n' "$passed" "$failed" "$total" "$logs"
    $native || printf 'Native desktop checks excluded; opt in with --native while idle.\n'
    $benchmarks || printf 'Benchmarks excluded; opt in with --benchmarks.\n'
    ((failed == 0))
fi
