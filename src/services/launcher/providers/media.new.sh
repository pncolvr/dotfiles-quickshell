#!/usr/bin/env bash

source "$(dirname -- "${BASH_SOURCE[0]}")/_common/utils.sh"
source "$HOME"/.config/qutebrowser/scripts/url/_common.sh

readonly TWITCH_FILE="$(get_temp_file_named twitch_online)"
readonly OPTIONS_FILE="$(get_temp_file_named local_player_options)"
readonly PICKER_HANDLE="$PICKER_HANDLER"
readonly TWITCH_URL_RE='^https?://(www\.)?twitch\.tv/([^/?#]+)'
readonly MPV_CLASS="mpv-twitch"
readonly CHAT_CLASS="qutebrowser-twitch-chat"

with_chat=false
title=""
url=""

function logged() { "$@" > >(log) 2> >(log_error); }

function parse_args() {
    while (( $# )); do
        case $1 in
            --chat) with_chat=true; shift;;
            --)     shift; break;;
            *)      break;;
        esac
    done
    title=${1:-}
    url=${2:-}
}

function build_menu() {
    if [[ -n $title && -n $url ]]; then
        write_single_entry_menu "$title" "$url" "$OPTIONS_FILE"
    else
        cp "$TWITCH_FILE" "$OPTIONS_FILE"
    fi
}

function write_single_entry_menu() {
    local entry_title=$1 entry_url=$2 output_file=$3
    local clean_url
    clean_url=$(clean "$entry_url")
    jq -n --arg title "$entry_title" --arg result "$clean_url" '{
        prompt: "",
        action: "output",
        allowTyped: false,
        allowMultipleSelection: false,
        sort: false,
        items: [ { title: $title, result: $result } ]
    }' > "$output_file"
}

function parse_twitch_channel() {
    if [[ $1 =~ $TWITCH_URL_RE ]]; then
        echo -n "${BASH_REMATCH[2]}"
    else
        show_error "Failed to parse Twitch channel"
        return 1
    fi
}

function open_twitch_chat() {
    local channel
    channel=$(parse_twitch_channel "$1") || return 1
    local chat_url="https://www.twitch.tv/popout/${channel}/chat?popout="
    "$ZDOTDIR"/scripts/default-browser/default-browser.sh "$CHAT_CLASS" "$chat_url"
}

function close_window() {
    logged hyprctl dispatch "hl.dsp.window.close({ window = \"$1\"})"
}

function close_twitch_chat() {
    close_window "class:$CHAT_CLASS"
}

function show_error() {
    logged hyprctl notify -1 3000 "rgb(FE8D59)" "$1"
}

function pause_player() {
    local needle=$1 player
    while read -r player; do
        if [[ $player == *"$needle"* ]]; then
            logged playerctl --player "$player" pause
            return 0
        fi
    done < <(playerctl --list-all 2>/dev/null)
}

function window_exists() {
    local class=$1 c
    while read -r c; do
        [[ $c == "$class" ]] && return 0
    done < <(hyprctl clients -j | jq -r '.[].class')
    return 1
}

function wait_for_window() {
    local class=$1 timeout=5 start=$SECONDS
    until window_exists "$class"; do
        if (( SECONDS - start >= timeout )); then
            log "timeout waiting for $class"
            return 1
        fi
        sleep 0.05
    done
}

function play() {
    local play_url=$1
    if [[ $play_url != *twitch* ]]; then
        show_error "Not a Twitch URL"
        return 1
    fi

    local mpv_pid
    close_window "class:$MPV_CLASS"
    close_twitch_chat

    logged mpv --force-window=immediate --wayland-app-id="$MPV_CLASS" "$play_url" &
    mpv_pid=$!

    if wait_for_window "$MPV_CLASS" && [[ $with_chat == true ]]; then
        open_twitch_chat "$play_url"
    fi

    wait "$mpv_pid" || show_error "Playback failed"

    close_twitch_chat
}

function main() {
    parse_args "$@"
    build_menu

    local count chosen code
    count=$(jq '.items | length' "$OPTIONS_FILE")
    if (( count == 0 )); then
        show_error "No links found"
        return 0
    fi

    chosen=$(bash "$PICKER_HANDLE" "$OPTIONS_FILE" 2> >(log_error))
    code=$?

    if [[ -n $chosen ]] && (( code == 0 )); then
        pause_player "chromium.instance"
        play "$chosen"
    fi
}

main "$@"
