#!/usr/bin/env bash
set -eo pipefail

provider_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$provider_dir/_common/utils.sh"
# set the following variables on the .env file
# VIDEOS_FOLDER=

loopback_id=''

cleanup_recording() {
    if [[ -n $loopback_id ]]; then
        pactl unload-module "$loopback_id" >/dev/null 2>&1 || true
        loopback_id=''
    fi
}
trap cleanup_recording EXIT

pick_option() {
    local prompt=$1
    shift
    printf '%s\n' "$@" | bash "$PICKER_LAUNCHER" --dmenu -i -no-custom -p "$prompt"
}

select_audio_device() {
    local kind=$1 default_device devices cards menu selection status=0
    case $kind in
        sinks) default_device=$(pactl get-default-sink) ;;
        sources) default_device=$(pactl get-default-source) ;;
    esac
    [[ -n $default_device ]] || return 1
    devices=$(pactl --format=json list "$kind") || return 1
    cards=$(pactl --format=json list cards) || return 1
    menu=$(mktemp "$(get_temp_dir)/recording-devices.XXXXXXXX.json") || return 1
    jq --arg default "$default_device" --arg kind "$kind" --argjson cards "$cards" '
        ($cards | map(select(.active_profile == "off")
            | (.index, .properties."object.id") | select(. != null) | tostring)) as $disabled
        | map((.card // .properties."device.id" // "" | tostring) as $card
            | select(($disabled | index($card)) == null)
            | select(.properties."device.profile.name" != "off"))
        | {
            prompt: (if $kind == "sinks" then "Audio output" else "Microphone" end),
            allowTyped: false, sort: false,
            items: (sort_by(.name != $default) | map({
                title: ((.description // .name) + (if .name == $default then " (default)" else "" end)),
                result: .name
            }))
        }' <<< "$devices" > "$menu" || { rm -f -- "$menu"; return 1; }
    selection=$(bash "$PICKER_LAUNCHER" --json "$menu") || status=$?
    rm -f -- "$menu"
    [[ $status == 0 && -n $selection ]] || return 1
    printf '%s\n' "$selection"
}

configure_audio() {
    local mode=$1 output_device microphone
    audio_source=''
    if [[ $mode == desktop || $mode == both ]]; then
        output_device=$(select_audio_device sinks) || return 1
        audio_source=$(pactl --format=json list sinks | jq -er --arg device "$output_device" \
            '.[] | select(.name == $device) | .monitor_source // empty') || return 1
    fi
    if [[ $mode == mic || $mode == both ]]; then
        microphone=$(select_audio_device sources) || return 1
        if [[ $mode == mic ]]; then
            audio_source=$microphone
        else
            loopback_id=$(pactl load-module module-loopback "source=$microphone" "sink=$output_device") || return 1
            # PipeWire needs a moment to register the microphone loopback.
            sleep 0.25
        fi
    fi
}

record_video() {
    local capture_mode output='' geometry='' fps audio_mode filename recorder_status=0
    local audio_source
    local -a command=(wf-recorder)

    capture_mode=$(pick_option Capture output region) || return 0
    case $capture_mode in
        output)
            output=$(hyprctl monitors -j | jq -r '.[].name' | sort \
                | bash "$PICKER_LAUNCHER" --dmenu -i -no-custom -p Output) || return 0
            [[ -n $output ]] || return 0
            command+=(--output "$output") ;;
        region)
            geometry=$(slurp -d) || return 0
            [[ -n $geometry ]] || return 0
            command+=(--geometry "$geometry") ;;
        *) return 0 ;;
    esac
    fps=$(pick_option Framerate 60 30 15) || return 0
    case $fps in 60|30|15) ;; *) return 0 ;; esac
    audio_mode=$(pick_option Audio none both desktop mic) || return 0
    case $audio_mode in none|both|desktop|mic) ;; *) return 0 ;; esac
    configure_audio "$audio_mode" || return 0

    mkdir -p -- "$VIDEOS_FOLDER"
    filename="$VIDEOS_FOLDER/$(date '+Recording %Y-%m-%d at %Hh%Mm%Ss').mp4"
    command+=(
        --codec hevc_nvenc
        --codec-param preset=p7
        --codec-param tune=hq
        --codec-param rc=vbr
        --codec-param cq=21
        --codec-param rc-lookahead=32
        --codec-param bf=3
        --codec-param spatial_aq=1
        --codec-param temporal_aq=1
        --codec-param aq-strength=10
        --framerate "$fps"
    )
    [[ -z $audio_source ]] || command+=("--audio=$audio_source")
    command+=(-f "$filename")

    hyprctl notify -1 1000 "rgb(2E7D32)" "recording starting" >/dev/null 2>&1 || true
    sleep 1.1
    printf '%q ' "${command[@]}"; printf '\n'
    "${command[@]}" || recorder_status=$?
    cleanup_recording

    if [[ $recorder_status != 0 || ! -s $filename ]]; then
        hyprctl notify -1 3000 "rgb(FF0000)" "recording error" >/dev/null 2>&1 || true
        return 1
    fi
    hyprctl notify -1 1000 "rgb(2E7D32)" "recording stopped" >/dev/null 2>&1 || true
    open_file_explorer "$filename"
}

# Stopping does not require configuration or reopen any picker.
if pgrep -xi wf-recorder >/dev/null; then
    pkill -SIGINT -x wf-recorder
else
    # recording.env contains only the destination folder.
    source "$(get_env_file "${BASH_SOURCE[0]}")"
    [[ -n ${VIDEOS_FOLDER:-} ]] || { printf 'VIDEOS_FOLDER is required in recording.env\n' >&2; exit 1; }
    record_video
fi
