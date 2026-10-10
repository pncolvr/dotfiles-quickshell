#!/usr/bin/env bash
# Real notification protocol on the private bus created by notifications.sh.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
entry="$NOTIFICATION_TEST_DIR/config/shell.qml"
database="$NOTIFICATION_TEST_DIR/config/data/quickshell.db"
log="$NOTIFICATION_TEST_DIR/qs.log"
signals="$NOTIFICATION_TEST_DIR/signals.log"
process='' monitor=''
cleanup() {
    local result=$?
    trap - EXIT
    if (( result != 0 )); then
        ipc snapshot >&2 || true
        cat "$log" "$signals" >&2 || true
    fi
    if [[ -n $process ]]; then kill "$process" 2>/dev/null || true; wait "$process" 2>/dev/null || true; fi
    if [[ -n $monitor ]]; then kill "$monitor" 2>/dev/null || true; wait "$monitor" 2>/dev/null || true; fi
    exit "$result"
}
trap cleanup EXIT
fail() { printf 'NOTIFICATION FAIL: %s\n' "$*" >&2; exit 1; }
# Poll commands directly; no eval or generated scripts. IPC is briefly unavailable during reload.
wait_for() {
    local message=$1 attempt
    shift
    for ((attempt=0; attempt<100; attempt++)); do
        if "$@"; then return; fi
        sleep 0.05
    done
    fail "$message"
}
ipc() { timeout 5 qs ipc -p "$entry" call notificationstest "$@"; }
toggle() { timeout 5 qs ipc -p "$entry" call notifications toggle >/dev/null; }
state() { ipc snapshot; }
rows() { ipc entries "${1:-desktop:test}" 100 0; }
json_is() { jq -e "$1" >/dev/null; }
state_is() { state 2>/dev/null | json_is "$1" 2>/dev/null; }
rows_are() { rows "${2:-desktop:test}" | json_is "$1"; }
check_state() { state_is "$1" || fail "${2:-$1}"; }
check_rows() { rows_are "$1" "${3:-desktop:test}" || fail "${2:-$1}"; }
ipc_true() { [[ $(ipc "$@") == true ]]; }
preference() { ipc_true preference "${3:-desktop:test}" "$1" "$2" || fail "preference $1"; }
bus_owned() {
    [[ $(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner org.freedesktop.Notifications) == '(true,)' ]]
}
bus_free() { ! bus_owned; }
ipc_ready() { qs ipc -p "$entry" show 2>/dev/null | rg -q notificationstest; }
start() {
    qs -p "$entry" >> "$log" 2>&1 & process=$!
    wait_for 'native server owns private bus' bus_owned
    wait_for 'test IPC available' ipc_ready
}
stop() {
    kill "$process"
    wait "$process" || true
    process=''
    wait_for 'private bus released' bus_free
}
quote() { jq -cn --arg text "$1" '$text'; }
protocol() {
    gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method "org.freedesktop.Notifications.$1" "${@:2}"
}
notify() {
    local summary=$1 body=Body app=Test desktop=test urgency=1 expiry=0 replacement=0 transient=false actions='[]' extra='' reply
    shift
    while (( $# )); do
        case $1 in
            body) body=$2;; app) app=$2;; desktop) desktop=$2;; urgency) urgency=$2;;
            timeout) expiry=$2;; replacement) replacement=$2;; transient) transient=$2;;
            actions) actions=$2;; extra) extra=$2;; *) fail "unknown notify argument: $1";;
        esac
        shift 2
    done
    reply=$(protocol Notify "$(quote "$app")" "$replacement" '""' "$(quote "$summary")" "$(quote "$body")" "$actions" \
        "{'urgency': <byte $urgency>, 'desktop-entry': <$(quote "$desktop")>, 'transient': <$transient>$extra}" "$expiry")
    [[ $reply =~ ^\(uint32\ ([0-9]+),\)$ ]] || fail "invalid Notify reply: $reply"
    printf '%s\n' "${BASH_REMATCH[1]}"
}
signal_seen() { rg -q "org.freedesktop.Notifications.$1 \\(uint32 $2, $3\\)" "$signals"; }
action_count() { rg -c "org.freedesktop.Notifications.ActionInvoked \\(uint32 $1," "$signals" || true; }
reload_seen() { [[ $(rg -c 'Configuration Loaded' "$log") -ge 2 ]]; }
native_is() { ipc nativeUi 2>/dev/null | json_is "$1" 2>/dev/null; }
legacy_opened() {
    if [[ ${NOTIFICATION_TEST_WAYLAND:-0} == 1 ]]; then
        [[ -f $NOTIFICATION_TEST_DIR/opened-urls && $(cat "$NOTIFICATION_TEST_DIR/opened-urls") == https://www.twitch.tv/ ]]
    else
        # Offscreen Qt records the requested URL but cannot invoke platform services.
        rg -Fq "QPlatformServices::openUrl() for 'https://www.twitch.tv/'" "$log"
    fi
}

QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 15 /usr/lib/qt6/bin/qmltestrunner \
    -input "$project_root/tests/notifications/tst_image-mask.qml" > "$NOTIFICATION_TEST_DIR/mask.log" 2>&1 \
    || { cat "$NOTIFICATION_TEST_DIR/mask.log"; fail 'image masks'; }
printf 'PASS: avatar padding detection, enclosed dark details, transparent and nonsquare images\n'
# Monitor remains attached across server restarts; readiness is confirmed before sending.
stdbuf -oL gdbus monitor --session --dest org.freedesktop.Notifications > "$signals" 2>&1 & monitor=$!
wait_for 'signal monitor starts' rg -q 'Monitoring signals' "$signals"
sqlite3 "$database" "CREATE TABLE preferences (key TEXT PRIMARY KEY, value_json TEXT NOT NULL); INSERT INTO preferences VALUES ('preserve', '42'); PRAGMA user_version=1;"
start
check_state '.dnd == false and (.groups | length) == 0'
low=$(notify Low urgency 0)
transient=$(notify Transient transient true)
normal=$(notify Normal)
critical=$(notify Critical urgency 2)
wait_for 'all notifications tracked' state_is '(.live | length) == 4'
check_rows 'length == 3 and any(.summary == "Low" and .urgency == 0) and .[0].summary == "Critical"' 'all urgencies archived; transient excluded'
for identifier in "$low" "$normal" "$critical"; do
    ipc prepareCard "$identifier" false
    check_state '.card.outlineVisible and .card.progress == 1' 'persistent popup has complete outline'
done
sleep 0.2
check_state '.card.progress == 1' 'persistent outline does not drain'
ipc prepareCard "$critical" true
check_state '.card.outlineVisible == false' 'history uses static border'
ipc prepareCard "$critical" false
check_state '.emitters["desktop:test"] | [.muted,.allowDuringDnd,.excludeFromHistory] | all(. == false)'
other=$(notify 'Other emitter' app Other desktop other)
check_state '.groups[0].emitterKey == "desktop:other"' 'groups ordered newest first'
ipc clearEmitter desktop:other
check_rows 'length == 3'
check_state ".emitters[\"desktop:other\"] != null and all(.live[]; .id != $other)"
deleted_key=desktop:delete-test
delete_saved=$(notify 'Delete saved' app 'Delete test' desktop delete-test)
delete_transient=$(notify 'Delete transient' app 'Delete test' desktop delete-test transient true)
check_rows 'length == 1' 'transient excluded from emitter history' "$deleted_key"
for field in muted allowDuringDnd excludeFromHistory; do preference "$field" true "$deleted_key"; done
ipc filter All >/dev/null
ipc searchEmitters ' DELETE TEST ' | json_is '["desktop:delete-test"] == .' || fail 'case-insensitive trimmed search'
ipc searchEmitters delete-test | json_is '["desktop:delete-test"] == .' || fail 'application ID search'
ipc searchEmitters missing-emitter | json_is 'length == 0' || fail 'unmatched search'
ipc searchEmitters test >/dev/null
ipc filter Hidden | json_is '["desktop:delete-test"] == .' || fail 'search composes with filter'
ipc_true clearEmitterSearch || fail 'search clears'
untouched_emitters=$(state | jq -c '.emitters | del(.["desktop:delete-test"])')
untouched_live=$(state | jq -c "[.live[] | select(.id != $delete_saved and .id != $delete_transient) | .id] | sort")
ipc prepareSettings 'History off'
wait_for 'delete button clicked' ipc_true settingsButton "notificationDeleteEmitter_$deleted_key"
wait_for 'emitter deleted' state_is '.emitters["desktop:delete-test"] == null'
wait_for 'notifications dismissed' state_is "all(.live[]; .id != $delete_saved and .id != $delete_transient)"
for identifier in "$delete_saved" "$delete_transient"; do wait_for 'dismissal signal' signal_seen NotificationClosed "$identifier" 'uint32 2'; done
check_rows 'length == 0' 'deleted emitter history gone' "$deleted_key"
check_state "all(.groups[]; .emitterKey != \"$deleted_key\") and .emitters == $untouched_emitters and .dnd == false and ([.live[].id] | sort) == $untouched_live"
check_rows 'length == 3'
[[ $(sqlite3 "$database" "SELECT count(*) FROM notification_live WHERE live_token LIKE '%/$delete_saved' OR live_token LIKE '%/$delete_transient';") == 0 ]] || fail 'deleted emitter live state removed'
if [[ ${NOTIFICATION_TEST_WAYLAND:-0} == 1 ]]; then
    wait_for 'native manager opens' native_is '.managerVisible'
    ipc nativeUi | json_is '.popupVisible and (.regularTooltipVisible == false) and .popupNamespace == "quickshell-private" and .managerNamespace == "quickshell-private" and .popupWidth > 0 and .popupWidth <= .screenWidth and .managerHeight > 0 and .managerHeight <= .screenHeight and .managerTab == "History"' || fail 'native surfaces bounded'
    ipc_true managerTab 1 || fail 'Emitters tab'
    wait_for 'Emitters selected' native_is '.managerTab == "Emitters"'
    ipc_true managerTab 0 || fail 'History tab'
    wait_for 'History selected' native_is '.managerTab == "History"'
    ipc_true preview /tmp/quickshell-notifications-preview.png || fail 'manager preview'
fi
toggle
check_state '.dnd and (.popups | length) == 0'
blocked=$(notify 'Critical blocked' urgency 2 extra ", 'SWAYNC_BYPASS_DND': <true>")
check_state '(.popups | length) == 0' 'sender cannot bypass DND'
preference allowDuringDnd true
check_state '(.popups | length) == 0' 'whitelisting does not replay'
allowed=$(notify Allowed)
check_state "[.popups[].id] == [$allowed]"
preference muted true
ipc filter Hidden | json_is '. == ["desktop:test"]' || fail 'hidden filter'
silent=$(notify 'Muted but saved')
check_state '(.popups | length) == 0'
check_rows '.[0].summary == "Muted but saved"'
preference muted false
check_state '(.popups | length) == 0' 'unmuting does not replay'
preference excludeFromHistory true
before=$(rows | jq length)
excluded=$(notify 'Never saved')
check_rows "length == $before"
notify 'Excluded replacement' replacement "$silent" >/dev/null
wait_for 'replacement received' state_is 'any(.popups[]; .summary == "Excluded replacement")'
check_rows 'all(.summary != "Excluded replacement")' 'excluded replacement does not overwrite archive'
for filter in 'History off' 'DND allowed'; do ipc filter "$filter" | json_is '. == ["desktop:test"]' || fail "$filter"; done
preference excludeFromHistory false
replacement=$(notify Updated replacement "$allowed")
wait_for 'replacement archived' rows_are 'any(.summary == "Updated")'
[[ $replacement == "$allowed" ]] || fail 'replacement ID preserved'
check_rows "length == $before"
toggle
check_state '.dnd == false'
timed=$(notify Timed timeout 150)
wait_for 'expiry closes live notification' state_is "all(.live[]; .id != $timed)"
check_rows 'any(.summary == "Timed")'
wait_for 'expiry reason' signal_seen NotificationClosed "$timed" 'uint32 1'
hovered=$(notify 'Hover timer' timeout 1200)
ipc prepareCard "$hovered" false
ipc cardHover true
wait_for 'hover pauses timer' state_is '.card.paused'
paused_progress=$(state | jq '.card.progress')
check_state '.card.outlineVisible and .card.progress > 0 and .card.progress <= 1'
sleep 1.4
check_state "any(.live[]; .id == $hovered) and ((.card.progress - $paused_progress) | fabs) < 0.001" 'hover freezes expiry and outline'
ipc cardHoverClose
check_state '.card.paused' 'close button keeps timer paused'
notify 'Hover replacement' replacement "$hovered" timeout 1000 >/dev/null
wait_for 'replacement resets paused timeout' state_is "any(.live[]; .id == $hovered and .deadline >= -1000 and .deadline < 0)"
ipc cardHover false
wait_for 'leaving resumes timer' state_is "any(.live[]; .id == $hovered and .deadline > 0)"
wait_for 'resumed expiry' state_is "all(.live[]; .id != $hovered)"
check_rows 'any(.summary == "Hover replacement")'
title_only=$(notify-send --print-id --expire-time=150 'Title only')
wait_for 'title-only CLI history' rows_are 'any(.summary == "Title only" and .body == "")' app:notify-send
wait_for 'title-only expiry' state_is "all(.live[]; .id != $title_only)"
check_rows 'length == 1' 'CLI history retained' app:notify-send
if [[ ${NOTIFICATION_TEST_WAYLAND:-0} == 1 ]]; then
    wait_for 'CLI group in manager' native_is 'any(.groups[]; .emitterKey == "app:notify-send")'
fi
ipc twitchNotify streamer_online
wait_for 'Twitch received' state_is 'any(.live[]; .summary == "Live")'
twitch_id=$(state | jq '.live[] | select(.summary == "Live") | .id')
ipc prepareCard "$twitch_id" false
wait_for 'Twitch image in icon slot' state_is '.card.imageIsIcon and (.card.icon | length) > 0'
check_state '.emitters["app:twitch"].name == "Twitch"'
wait_for 'Twitch icon archived' rows_are 'any(.summary == "Live" and (.image | startswith("data:image/png;base64,")))' app:twitch
if [[ ${NOTIFICATION_TEST_WAYLAND:-0} == 1 ]]; then ipc_true preview /tmp/quickshell-notifications-twitch-preview.png || fail 'Twitch preview'; fi
twitch_archive=$(rows app:twitch | jq -r '.[] | select(.summary == "Live") | .archiveId')
check_rows 'any(.summary == "Live" and .urgency == 1 and .body == "`streamer_online`" and .actions == [])' 'Twitch normal urgency and no actions' app:twitch
check_state '.card.actionStates == []'
ipc_true prepareHistory "$twitch_archive" || fail 'Twitch history card'
sleep 0.1
check_state '.card.actionStates == []'
ipc dismiss "$twitch_id"
body_only=$(notify '' body 'Body without title' timeout 150)
wait_for 'empty summary saved' rows_are 'any(.summary == "" and .body == "Body without title")'
wait_for 'body-only expiry' state_is "all(.live[]; .id != $body_only)"
acted=$(notify 'Default action' actions "['default', 'Open', 'custom', 'Custom']")
ipc cardClick "$acted" false
wait_for 'default invoked' signal_seen ActionInvoked "$acted" "'default'"
[[ $(action_count "$acted") == 1 ]] || fail 'one default action'
check_state "all(.live[]; .id != $acted)"
archived_action=$(rows | jq -r '.[] | select(.summary == "Default action") | .archiveId')
check_rows 'any(.summary == "Default action" and .actions == [{identifier:"default",text:"Open"},{identifier:"custom",text:"Custom"}])'
ipc_true prepareHistory "$archived_action" || fail 'action history'
sleep 0.1
check_state '.card.actionStates == [] and .card.buttonFound == false'
[[ $(ipc historyAction "$archived_action" custom) == false ]] || fail 'expired callback rejected'
[[ $(ipc historyButton notificationAction_custom) == false ]] || fail 'history hides buttons'
action_update=$(notify 'Action replacement' actions "['first', 'First']")
action_archive=$(rows | jq -r '.[] | select(.summary == "Action replacement") | .archiveId')
notify 'Action replacement updated' replacement "$action_update" actions "['second', 'Second']" >/dev/null
wait_for 'action replacement metadata' rows_are "any(.archiveId == \"$action_archive\" and .actions == [{identifier:\"second\",text:\"Second\"}])"
ipc dismiss "$action_update"
resident=$(notify Resident actions "['default', 'Open', 'custom', 'Custom']" extra ", 'resident': <true>")
ipc prepareCard "$resident" true
check_state '.card.actionStates == []' 'history hides live actions'
ipc prepareCard "$resident" false
sleep 0.1
wait_for 'action button clicked' ipc_true cardButton "$resident" notificationAction_custom false
wait_for 'custom invoked' signal_seen ActionInvoked "$resident" "'custom'"
[[ $(action_count "$resident") == 1 ]] || fail 'custom button does not invoke default'
check_state "any(.live[]; .id == $resident)" 'resident stays live'
ipc cardClick "$resident" true
wait_for 'right-click dismisses' state_is "all(.live[]; .id != $resident)"
check_rows 'any(.summary == "Resident")'
source=$(notify 'Source controls' actions "['default', 'Open']")
ipc prepareEmitter "$source"
sleep 0.1
wait_for 'emitter mute button' ipc_true emitterButton notificationMute
check_state '.emitters["desktop:test"].muted'
! signal_seen ActionInvoked "$source" "'default'" || fail 'emitter controls cannot activate card'
preference muted false
ipc_true focusFallback || fail 'focus fallback'
unmatched=$(notify 'Unmatched window' app Unmatched desktop unmatched)
ipc activate "$unmatched"
check_state '.focusMessage == "No matching application window is available."'
sleep 1.7
ipc activate "$unmatched"
sleep 1.7
check_state '(.focusMessage | length) > 0' 'click restarts feedback timer'
wait_for 'feedback clears' state_is '.focusMessage == ""'
ipc activate "$unmatched"
ipc activate "$source"
check_state '.focusMessage == ""'
ipc dismiss "$unmatched"
closed=$(notify 'Client close')
protocol CloseNotification "$closed" >/dev/null
wait_for 'client closure' state_is "all(.live[]; .id != $closed)"
check_rows 'any(.summary == "Client close")'
imaged=$(notify Image extra ", 'image-data': <(1, 1, 4, true, 8, 4, [byte 0xff, 0x00, 0x00, 0xff])>")
wait_for 'raw image persisted' rows_are 'any(.summary == "Image" and (.image | startswith("data:image/png;base64,")))'
for offset in 0 2; do ipc entries desktop:test 2 "$offset" | json_is 'length == 2' || fail 'pagination'; done
reload_id=$(notify 'Reload timer' timeout 5000)
before_state=$(state)
deadline=$(jq ".live[] | select(.id == $reload_id) | .deadline" <<< "$before_state")
group_count=$(jq '[.groups[].count] | add' <<< "$before_state")
printf '\n// reload probe\n' >> "$entry"
wait_for 'hot reload' reload_seen
wait_for 'carried notification reconciled' state_is "any(.live[]; .id == $reload_id)"
check_state "any(.live[]; .id == $reload_id and .deadline == $deadline) and ([.groups[].count] | add) == $group_count" 'reload preserves deadline and archive count'
toggle
preference muted true
preference excludeFromHistory true
saved_count=$(rows | jq length)
stop
start
check_rows "length == $saved_count"
check_state '.dnd and .popups == [] and .live == [] and .emitters["desktop:delete-test"] == null'
check_rows 'length == 0' 'deleted emitter stays deleted' "$deleted_key"
returned=$(notify 'Returned emitter' app 'Delete test' desktop delete-test)
check_state ".emitters[\"$deleted_key\"] | [.muted,.allowDuringDnd,.excludeFromHistory] | all(. == false)"
check_rows '.[0].summary == "Returned emitter"' 'new emitter defaults' "$deleted_key"
check_state "all(.popups[]; .id != $returned)"
ipc dismiss "$returned"
check_rows '.[0].summary == "Title only" and .[0].body == ""' 'CLI restart history' app:notify-send
check_rows 'any(.summary == "Low" and .urgency == 0)' 'low urgency restart history'
check_rows 'any(.summary == "Live" and (.image | startswith("data:image/png;base64,")))' 'Twitch restart history' app:twitch
for archive in "$archived_action" "$twitch_archive"; do
    ipc_true prepareHistory "$archive" || fail 'restart history card'
    sleep 0.1
    check_state '.card.actionStates == []'
done
check_state '.emitters["desktop:test"].muted and .emitters["desktop:test"].excludeFromHistory'
check_rows 'any(.summary == "Image" and (.image | startswith("data:image/png;base64,")))'
ipc clearAll
check_rows 'length == 0'
check_state '.emitters["desktop:test"] != null and .dnd'
stop
start
check_rows 'length == 0'
check_state '.emitters["desktop:test"].excludeFromHistory'
[[ $(sqlite3 "$database" "PRAGMA user_version; PRAGMA integrity_check; SELECT value_json FROM preferences WHERE key='preserve';") == $'7\nok\n42' ]] || fail 'schema integrity and unrelated preferences'
stop
sqlite3 "$database" <<'SQL'
ALTER TABLE notifications DROP COLUMN actions_json;
ALTER TABLE notifications DROP COLUMN action_handler;
PRAGMA user_version=2;
INSERT INTO notifications VALUES ('legacy-twitch','app:twitch','Legacy Twitch','Preserved',0,1,1,'');
INSERT INTO notifications VALUES ('legacy-generic','desktop:test','Legacy app','Preserved',1,2,2,'');
SQL
start
check_rows '.[0].body == "Preserved"' 'v2 Twitch history' app:twitch
check_rows '.[0].body == "Preserved" and .[0].actions == []' 'v2 generic callbacks not invented'
check_state '.emitters["desktop:test"].excludeFromHistory and .dnd'
ipc_true prepareHistory legacy-twitch || fail 'legacy history card'
sleep 0.1
check_state '.card.actionStates == []'
ipc historyClick
wait_for 'legacy local Twitch action' legacy_opened
stop
! rg -n 'Failed to load configuration|Binding loop detected|TypeError:|ReferenceError:|NOTIFICATION FAIL:|Local database:' "$log" || fail 'QML log errors'
printf 'PASS: private D-Bus lifecycle, policy, actions/clicks, image archive, hot reload, migration and restart persistence\n'
