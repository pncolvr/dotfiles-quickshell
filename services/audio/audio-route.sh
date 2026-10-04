#!/usr/bin/env bash
# Move current PulseAudio-compatible apps without changing the system default.
set -euo pipefail

fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# -ge 2 ]] || fail 'Usage: audio-route.sh input|output DEVICE_NAME [STREAM_SERIAL ...]'
direction=$1
target=$2
shift 2
targeted=false
serials='[]'
if (( $# > 0 )); then
    targeted=true
    for serial in "$@"; do
        [[ $serial =~ ^[0-9]+$ ]] || fail 'Choose a running audio app.'
    done
fi
case $direction in
    output) devices=sinks; streams=sink-inputs; move=move-sink-input ;;
    input) devices=sources; streams=source-outputs; move=move-source-output ;;
    *) fail 'Choose input or output.' ;;
esac
[[ -n $target ]] || fail 'Choose an audio device.'
for dependency in pactl jq timeout; do
    command -v "$dependency" >/dev/null || fail "Switching current apps requires $dependency."
done

pulse() { timeout 5 pactl "$@"; }
if $targeted; then serials=$(printf '%s\n' "$@" | jq -Rsc 'split("\n") | map(select(length > 0))'); fi
device_list=$(pulse -f json list "$devices") || fail 'Could not read the available audio devices.'
jq -e --arg name "$target" --arg direction "$direction" '
    any(.[]; .name == $name and ($direction == "output" or
        ((.monitor_source // "") == "" and .monitor_of_sink == null and (.name | endswith(".monitor") | not))))
' <<< "$device_list" >/dev/null || fail 'That audio device is no longer available.'

stream_list=$(pulse -f json list "$streams") || fail 'Could not read the current audio apps.'
# Filter-chain plumbing and our activity monitor are not application streams.
indices=$(jq -r --argjson serials "$serials" --argjson targeted "$targeted" '
    .[] | select((.properties["application.name"] // "") != "")
    | select(.properties["application.name"] != "Quickshell Peak Detect")
    | select(.properties["node.name"] != "quickshell-peak-monitor")
    | . as $stream
    | select(($targeted | not) or ($serials | index($stream.properties["object.serial"] | tostring)))
    | [.index, (.properties["object.serial"] // "")] | @tsv
' <<< "$stream_list") || fail 'Could not read the current audio apps.'

count=0
while IFS=$'\t' read -r index serial; do
    [[ -n $index ]] || continue
    if pulse "$move" "$index" "$target" >/dev/null 2>&1; then
        count=$((count + 1))
    else
        # Apps can close while the snapshot is being routed; that is harmless.
        current=$(pulse -f json list "$streams") || fail 'Could not switch the current audio apps.'
        if jq -e --argjson index "$index" --arg serial "$serial" '
            any(.[]; .index == $index and ((.properties["object.serial"] // "" | tostring) == $serial))
        ' <<< "$current" >/dev/null; then
            fail 'Could not switch an app. The audio device may have disconnected.'
        fi
    fi
done <<< "$indices"

if $targeted; then
    (( count > 0 )) || fail 'That app is no longer using audio.'
    printf 'Switched this app. The default device is unchanged.\n'
elif (( count == 0 )); then
    printf 'No compatible apps to switch. Set default to use this device for new apps.\n'
elif (( count == 1 )); then
    printf 'Switched 1 app. The default device is unchanged.\n'
else
    printf 'Switched %s apps. The default device is unchanged.\n' "$count"
fi
