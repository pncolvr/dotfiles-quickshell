#!/usr/bin/env bash
# Move current PulseAudio-compatible apps without changing the system default.
set -euo pipefail

fail() { jq -nc --arg key "$1" --argjson args "${2:-[]}" '{key:$key,args:$args}' >&2; exit 1; }
[[ $# -ge 2 ]] || fail 'Usage: audio-route.sh input|output DEVICE_NAME [STREAM_SERIAL ...]'
direction=$1
target=$2
shift 2
targeted=false
serials='[]'
if (( $# > 0 )); then
    targeted=true
    for serial in "$@"; do
        [[ $serial =~ ^[0-9]+$ ]] || fail 'audio.route.errors.runningApp'
    done
fi
case $direction in
    output) devices=sinks; streams=sink-inputs; move=move-sink-input ;;
    input) devices=sources; streams=source-outputs; move=move-source-output ;;
    *) fail 'audio.route.errors.direction' ;;
esac
[[ -n $target ]] || fail 'audio.route.errors.deviceRequired'
for dependency in pactl jq timeout; do
    command -v "$dependency" >/dev/null || fail audio.route.errors.dependency "$(jq -nc --arg tool "$dependency" '[$tool]')"
done

pulse() { timeout 5 pactl "$@"; }
if $targeted; then serials=$(printf '%s\n' "$@" | jq -Rsc 'split("\n") | map(select(length > 0))'); fi
device_list=$(pulse -f json list "$devices") || fail 'audio.route.errors.readDevices'
jq -e --arg name "$target" --arg direction "$direction" '
    any(.[]; .name == $name and ($direction == "output" or
        ((.monitor_source // "") == "" and .monitor_of_sink == null and (.name | endswith(".monitor") | not))))
' <<< "$device_list" >/dev/null || fail 'audio.route.errors.deviceUnavailable'

stream_list=$(pulse -f json list "$streams") || fail 'audio.route.errors.readApps'
# Filter-chain plumbing and our activity/spectrum monitors are not application streams.
indices=$(jq -r --argjson serials "$serials" --argjson targeted "$targeted" '
    .[] | select((.properties["application.name"] // "") != "")
    | select(.properties["application.name"] != "Quickshell Peak Detect")
    | select(.properties["node.name"] != "quickshell-peak-monitor")
    | select(.properties["application.name"] != "Quickshell Spectrum Detect")
    | select(.properties["node.name"] != "quickshell-spectrum-monitor")
    | . as $stream
    | select(($targeted | not) or ($serials | index($stream.properties["object.serial"] | tostring)))
    | [.index, (.properties["object.serial"] // "")] | @tsv
' <<< "$stream_list") || fail 'audio.route.errors.readApps'

count=0
while IFS=$'\t' read -r index serial; do
    [[ -n $index ]] || continue
    if pulse "$move" "$index" "$target" >/dev/null 2>&1; then
        count=$((count + 1))
    else
        # Apps can close while the snapshot is being routed; that is harmless.
        current=$(pulse -f json list "$streams") || fail 'audio.route.errors.switchApps'
        if jq -e --argjson index "$index" --arg serial "$serial" '
            any(.[]; .index == $index and ((.properties["object.serial"] // "" | tostring) == $serial))
        ' <<< "$current" >/dev/null; then
            fail 'audio.route.errors.switchApp'
        fi
    fi
done <<< "$indices"

if $targeted; then
    (( count > 0 )) || fail 'audio.route.errors.appStopped'
    jq -nc '{key:"audio.route.status.app"}'
elif (( count == 0 )); then
    jq -nc '{key:"audio.route.status.empty"}'
elif (( count == 1 )); then
    jq -nc '{key:"audio.route.status.apps",count:1}'
else
    jq -nc --argjson count "$count" '{key:"audio.route.status.apps",count:$count}'
fi
