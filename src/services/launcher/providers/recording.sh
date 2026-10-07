#!/usr/bin/env bash

WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$WORKSPACE"/_common/utils.sh
source "$(get_env_file "${BASH_SOURCE[0]:-0}")"
# set the following variables on the .env file
# VIDEOS_FOLDER=
# HEADPHONES=
# MIC=

LOOPBACK_ID_FILE="$(get_temp_file_named loopback_id)"
SCREENCAST_STATUS_FILE="$(get_temp_file_named screencast_status)"

function handle_capture_output() {
    outputs=$(hyprctl monitors -j | jq --raw-output '.[] | .name')
    output=$(printf '%s\n' "${outputs[@]}" | sort | bash "$PICKER_LAUNCHER" --dmenu -i -p "")
    if [[ -n "$output" ]]; then
        capture "$output" ""
    fi
}

function handle_capture_region() {
    capture "" "$(slurp -d)"
}

function handle_audio_choice() {
    include=$(printf "none\nboth\ndesktop\nmic" | bash "$PICKER_LAUNCHER" --dmenu -i -p "")
    case "$include" in
        none) echo -n "";;
        desktop) echo -n "$HEADPHONES";;
        mic) echo -n "$MIC";;
        both)
            load_loopback
            echo -n "$HEADPHONES";;
        *) exit 1;;
    esac
}

function load_loopback() {
    : > "$LOOPBACK_ID_FILE"
    local id

    id=$(pactl load-module module-loopback) && echo "$id" >> "$LOOPBACK_ID_FILE"

    # Give PipeWire time to register nodes
    sleep 0.25
}

function unload_loopback() {
    [[ -f "$LOOPBACK_ID_FILE" ]] || return
    while read -r mid; do
        [[ -n "$mid" ]] && pactl unload-module "$mid" >/dev/null 2>&1 || true
    done < "$LOOPBACK_ID_FILE"
    rm -f "$LOOPBACK_ID_FILE"
}

function request_fps () {
    fps=$(printf "60\n30\n15" | bash "$PICKER_LAUNCHER" --dmenu -i -p "")
    case "$fps" in
        60|30|15) echo "$fps";;
        *) exit 1;;
    esac
}

function capture () {
    local output=$1
    local region=$2

    # Need at least one of output or region to know what to capture.
    [[ -z "$output" && -z "$region" ]] && exit 0

    local audio
    local filename
    local file
    local params=" "
    fps=$(request_fps)
    [ -z "$fps" ] && exit 0
    audio=$(handle_audio_choice)
    [ -n "$output" ] && params+=" --output $output"
    [ -n "$region" ] && params+=" --geometry \"$region\""
    file=$(date '+%Y-%m-%d_%H:%M:%S').mp4
    mkdir -p "$VIDEOS_FOLDER"
    filename="$VIDEOS_FOLDER/$file"

    hyprctl notify -1 1000 "rgb(2E7D32)" "recording starting" > /dev/null 2>&1
    sleep 1.1
    command="wf-recorder $params \
        --codec hevc_nvenc \
        --codec-param preset=p7 \
        --codec-param tune=hq \
        --codec-param rc=vbr \
        --codec-param cq=21 \
        --codec-param rc-lookahead=32 \
        --codec-param bf=3 \
        --codec-param spatial_aq=1 \
        --codec-param temporal_aq=1 \
        --codec-param aq-strength=10 \
        --framerate $fps"

    [ -n "$audio" ] && command+=" --audio=$audio"

    command+=" -f \"$filename\""

    echo "$command"
    cast_status=$(cat "$SCREENCAST_STATUS_FILE")
    echo "1" > "$SCREENCAST_STATUS_FILE"
    eval "$command"
    status=$?
    echo "$status"
    if [[ $status -ne 0 ]]; then
        hyprctl notify -1 3000 "rgb(FF0000)" "recording error" > /dev/null 2>&1
    fi

    unload_loopback
    echo "$cast_status" > "$SCREENCAST_STATUS_FILE"
    # systemctl --user restart pipewire pipewire-pulse
    hyprctl notify -1 1000 "rgb(2E7D32)" "recording stopped" > /dev/null 2>&1
    open_file_explorer "$filename"
}

function handle_capture() {
    chosen=$(printf "output\nregion" | bash "$PICKER_LAUNCHER" --dmenu -i -p "")
    case $chosen in
        *output*) handle_capture_output;;
        *region*) handle_capture_region;;
        *)exit 0;;
    esac
}

function handle_stop() {
    pkill -SIGINT wf-recorder
}

if ! pgrep -xi "wf-recorder" > /dev/null
then
    handle_capture
else
    handle_stop
fi
