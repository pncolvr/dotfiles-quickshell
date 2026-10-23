#!/usr/bin/env bash
# Run explicit suite entry points, not fixture helpers or mock executables.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
native=false
benchmarks=false
list=false
selected_suites=()
declare -A matched_suites=()
for option in "$@"; do
    case "$option" in
        --native) native=true ;;
        --benchmarks) benchmarks=true ;;
        --list) list=true ;;
        --help|-h)
            printf 'Usage: bash tests/run.sh [--native] [--benchmarks] [--list] [SUITE ...]\n'
            printf 'Default: isolated suites. --native adds desktop checks; leave keyboard/mouse idle.\n'
            printf 'Optional exact suite names (e.g. ui/module-pins audio/controls) select a subset.\n'
            printf 'Use isolated/NAME or native/NAME to select a specific mode; native still requires --native.\n'
            printf 'Logs are retained under /tmp. TEST_TIMEOUT sets the per-suite limit (default 180 seconds).\n'
            exit 0 ;;
        -*) printf 'Unknown option: %s\n' "$option" >&2; exit 2 ;;
        *) selected_suites+=("$option") ;;
    esac
done
native_checks=$native
if ! $list && ((${#selected_suites[@]})); then
    # Validate every name before starting any suite or creating a private bus.
    selection_catalog=$(bash "$0" --list "$@") || exit 2
    native_checks=false
    if [[ $selection_catalog == native$'\t'* || $selection_catalog == *$'\nnative\t'* ]]; then native_checks=true; fi
fi
if $native_checks && ! $list && [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'Native suites require a running Wayland session.\n' >&2
    exit 2
fi
if ! $list && [[ ${QS_TEST_RUNNER_BUS:-0} != 1 ]]; then
    if $native; then
        # Test services use a private bus; status notifications belong on the desktop.
        exec dbus-run-session -- env QS_TEST_RUNNER_BUS=1 \
            QS_TEST_DESKTOP_BUS="${DBUS_SESSION_BUS_ADDRESS:-}" \
            bash "$repo/tests/runner/session.sh" bash "$0" "$@"
    fi
    # Activation helpers inherit the bus daemon's environment, not each client's.
    exec env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u DISPLAY \
        dbus-run-session -- env QS_TEST_RUNNER_BUS=1 \
            bash "$repo/tests/runner/session.sh" bash "$0" "$@"
fi
cd -- "$repo"
# A test crash must exit once, without replaying the fixture or opening a crash UI.
export QS_DISABLE_CRASH_HANDLER=1
run_started=$SECONDS
limit=${TEST_TIMEOUT:-180}
[[ $limit =~ ^[1-9][0-9]*$ ]] || { printf 'TEST_TIMEOUT must be a positive number of seconds.\n' >&2; exit 2; }
passed=0
failed=0
total=0
skipped=0
tests_passed=0
tests_failed=0
tests_skipped=0
failed_suites=()
green=''
red=''
reset=''
interactive=false
if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
    interactive=true
    if [[ ! -v NO_COLOR ]]; then
        green=$'\e[32m'
        red=$'\e[31m'
        reset=$'\e[0m'
    fi
fi
native_running=false
native_notification_id=''
desktop_bus=${QS_TEST_DESKTOP_BUS:-}

format_duration() {
    local seconds=$1 hours minutes
    hours=$((seconds / 3600))
    minutes=$((seconds / 60 % 60))
    seconds=$((seconds % 60))
    if ((hours > 0)); then printf '%sh %sm %ss' "$hours" "$minutes" "$seconds"
    elif ((minutes > 0)); then printf '%sm %ss' "$minutes" "$seconds"
    else printf '%ss' "$seconds"; fi
}

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
    body="You can use the keyboard and mouse now."$'\n'"Tests: $tests_passed passed, $tests_failed failed."
    if [[ $native_notification_id =~ ^[1-9][0-9]*$ ]]; then
        notify_native --replace-id="$native_notification_id" --urgency=normal \
            --expire-time=8000 "$summary" "$body" >/dev/null 2>&1 || true
    fi
    printf '%s. You can use the keyboard and mouse now.\n' "$summary"
}
if ! $list; then
    logs=$(mktemp -d /tmp/quickshell-tests.XXXXXXXX)
    printf 'Logs: %s\n' "$logs"
    printf 'status\tseconds\tsuite\tlog\tmode\tpassed\tfailed\tskipped\n' > "$logs/results.tsv"
    printf 'status\tmode\tsuite\ttest\tlog\n' > "$logs/tests.tsv"
    trap 'printf "\nInterrupted; logs: %s\n" "$logs" >&2; exit 130' INT
    trap 'printf "\nStopped; logs: %s\n" "$logs" >&2; exit 143' TERM
    trap 'finish_native "$?"' EXIT
fi
run() {
    local mode=$1 name=$2
    shift 2
    if ((${#selected_suites[@]})); then
        local selector selected=false
        for selector in "${selected_suites[@]}"; do
            if [[ $selector == "$name" || $selector == "$mode/$name" ]]; then
                matched_suites["$selector"]=1
                selected=true
            fi
        done
        $selected || return 0
    fi
    if $list; then
        printf '%s\t%s\t' "$mode" "$name"
        printf '%q ' "$@"
        printf '\n'
        return
    fi
    total=$((total + 1))
    local log="$logs/$(printf '%03d' "$total")-${name//\//-}.log"
    local started=$SECONDS status=0
    if $interactive; then printf 'RUN  %s/%s' "$mode" "$name"; fi
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
    local cases="$log.tests.tsv" case_passed case_failed case_skipped
    awk -v mode="$mode" -v suite="$name" -v log_path="$log" -v exit_status="$status" \
        -v limit="$limit" -f "$repo/tests/runner/results.awk" "$log" > "$cases"
    cat "$cases" >> "$logs/tests.tsv"
    read -r case_passed case_failed case_skipped < <(awk -F '\t' '
        $1 == "PASS" { passed++ } $1 == "FAIL" { failed++ } $1 == "SKIP" { skipped++ }
        END { print passed+0, failed+0, skipped+0 }
    ' "$cases")
    tests_passed=$((tests_passed + case_passed))
    tests_failed=$((tests_failed + case_failed))
    tests_skipped=$((tests_skipped + case_skipped))
    if ((status == 0 && case_failed == 0 && case_passed == 0)); then
        skipped=$((skipped + 1))
        result=SKIP
    elif ((status == 0 && case_failed == 0)); then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_suites+=("$mode/$name ($log)")
        result=FAIL
    fi
    local color=''
    if [[ $result == PASS ]]; then color=$green; elif [[ $result == FAIL ]]; then color=$red; fi
    if $interactive; then printf '\r\033[2K'; fi
    printf '%s%s%s %s/%s (%s passed, %s failed, %s skipped; %ss; exit %s)\n' \
        "$color" "$result" "$reset" "$mode" "$name" "$case_passed" "$case_failed" "$case_skipped" "$elapsed" "$status"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$result" "$elapsed" "$name" "$log" \
        "$mode" "$case_passed" "$case_failed" "$case_skipped" >> "$logs/results.tsv"
}

run isolated runner/reporting bash tests/runner/reporting.sh
run isolated runner/session bash tests/runner/session-test.sh
run isolated qml/lint bash tests/qml/lint.sh
run isolated qml/singletons bash tests/qml/singletons.sh
run isolated qml/selection bash tests/qml/selection.sh
run isolated qml/button-focus bash tests/qml/button-focus.sh
run isolated qml/batched-model bash tests/qml/batched-model.sh
run isolated qml/pulse-clock bash tests/qml/pulse-clock.sh
run isolated qml/alerts bash tests/qml/alerts.sh
run isolated ui/copy-button bash tests/ui/copy-button.sh
run isolated ui/buttons bash tests/ui/buttons.sh
run isolated ui/scrollbar bash tests/ui/scrollbar.sh
run isolated i18n bash tests/i18n/run.sh
run isolated audio/controls bash tests/audio/audio.sh
run isolated audio/media bash tests/audio/media.sh
run isolated audio/artwork bash tests/audio/media-artwork.sh
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
run isolated hyprland/windows bash tests/hyprland/windows.sh
run isolated launcher/bridge bash tests/launcher/launcher.sh
run isolated launcher/prompts bash tests/launcher/prompts.sh
run isolated launcher/providers bash tests/launcher/providers.sh
run isolated launcher/provider-config bash tests/launcher/provider-config.sh
run isolated launcher/bookmarks bash tests/launcher/bookmarks.sh
run isolated browser/model node tests/browser/model.mjs
run isolated browser/desktop bash tests/browser/desktop.sh
run isolated browser/routing bash tests/browser/routing.sh
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
run isolated projects/model node --test --test-reporter=tap tests/projects/launchers.test.mjs
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
run isolated system/optional-collections bash tests/system/optional-collections.sh
run isolated time/calendar bash tests/time/calendar.sh
run isolated time/timers bash tests/time/timers.sh
run isolated recording/setup bash tests/recording/setup.sh
run isolated recording/worker bash tests/recording/worker.sh
run isolated ui/folder-dialog bash tests/ui/folder-dialog.sh
run isolated ui/keybinds bash tests/ui/keybinds.sh
run isolated ui/module-pins bash tests/ui/module-pins.sh
run isolated ui/panel-motion bash tests/ui/panel-motion.sh
run isolated ui/tooltip-height bash tests/ui/tooltip-height.sh
run isolated ui/adaptive-bar bash tests/ui/adaptive-bar.sh
run isolated ui/reload bash tests/ui/reload-warnings.sh
run isolated ui/rows bash tests/ui/rows.sh
run isolated ui/hints bash tests/ui/shortcut-hints.sh
run isolated ui/theme bash tests/ui/theme.sh
run isolated ui/hover bash tests/ui/tooltip-hover.sh
run isolated ui/search bash tests/ui/tooltip-search.sh

if $benchmarks; then
    run isolated benchmark/clipboard bash tests/clipboard/fts/benchmark.sh
    run isolated benchmark/projects bash tests/projects/grouping-benchmark.sh
fi
if $native; then
    if ! $list && $native_checks; then
        native_running=true
        printf '\nNative tests will start within 60 seconds.\nLeave keyboard and mouse idle.\n'
        native_notification_id=$(notify_native --print-id --urgency=critical --expire-time=0 \
            'Native tests starting' $'Tests will start within 60 seconds.\nLeave keyboard and mouse idle.') \
            || printf 'Desktop notification unavailable; follow the status in this terminal.\n' >&2
        sleep 60
        printf 'Native tests are now running.\nLeave keyboard and mouse idle.\n'
        notification_options=()
        if [[ $native_notification_id =~ ^[1-9][0-9]*$ ]]; then
            notification_options+=(--replace-id="$native_notification_id")
        fi
        native_notification_id=$(notify_native --print-id "${notification_options[@]}" --urgency=critical --expire-time=0 \
            'Native tests running' $'Tests are now running.\nLeave keyboard and mouse idle.') \
            || printf 'Desktop notification unavailable; follow the status in this terminal.\n' >&2
    fi
    # Explicit opt-in: these checks can take focus, move the pointer or use GPU capture.
    run native audio/imports bash tests/audio/audio.sh --native-imports
    run native audio/fullscreen bash tests/audio/media-fullscreen.sh
    run native audio/artwork bash tests/audio/media-artwork.sh --gpu
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
    run native launcher/clipboard-handoff bash tests/launcher/clipboard-handoff-native.sh
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
    run native ui/tooltip-dropdown bash tests/ui/tooltip-dropdown-native.sh
    run native ui/panel-host bash tests/ui/panel-host.sh
    run native ui/panel-input bash tests/ui/panel-input.sh
    run native ui/panel-shadow bash tests/ui/panel-shadow.sh
    run native ui/adaptive-bar env ADAPTIVE_NATIVE=1 bash tests/ui/adaptive-bar.sh
    run native ui/twitch bash tests/ui/twitch-panel.sh
    run native ui/unlock bash tests/ui/unlock-focus.sh
    finish_native
fi
for selector in "${selected_suites[@]}"; do
    if [[ ! -v matched_suites["$selector"] ]]; then
        printf 'Unknown or disabled suite: %s. Use --list, --native or --benchmarks as appropriate.\n' "$selector" >&2
        exit 2
    fi
done
if ! $list; then
    printf '\nSuites: %s passed, %s failed, %s skipped, %s total.\n' "$passed" "$failed" "$skipped" "$total"
    printf 'Tests: %s passed, %s failed, %s skipped, %s total.\n' \
        "$tests_passed" "$tests_failed" "$tests_skipped" "$((tests_passed + tests_failed + tests_skipped))"
    printf 'Total time: %s\n' "$(format_duration "$((SECONDS - run_started))")"
    if ((${#failed_suites[@]})); then
        printf '\nFailed suites:\n'
        printf '  %s\n' "${failed_suites[@]}"
        printf '\nFailed tests:\n'
        awk -F '\t' '$1 == "FAIL" { printf "  %s/%s: %s (%s)\n", $2, $3, $4, $5 }' "$logs/tests.tsv"
    fi
    printf '\nSuite results: %s/results.tsv\nAll test results: %s/tests.tsv\nLogs: %s\n' "$logs" "$logs" "$logs"
    $native || printf 'Native desktop checks excluded; opt in with --native while idle.\n'
    $benchmarks || printf 'Benchmarks excluded; opt in with --benchmarks.\n'
    ((failed == 0))
fi
