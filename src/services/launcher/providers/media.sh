#!/usr/bin/env bash

source "$(dirname -- "${BASH_SOURCE[0]}")/_common/utils.sh"
source "$HOME"/.config/qutebrowser/scripts/url/_common.sh
function show_error() {
    hyprctl notify -1 3000 "rgb(FE8D59)" "$1" > >(log) 2> >(log_error)
}

function pause_player() {
    v=$(playerctl --list-all | grep "$1")
    if [ -n "$v" ]; then
        playerctl --player "$v" pause > >(log) 2> >(log_error)
    fi
}

function get_source() {
    if [[ "$1" == *"twitch"* ]]; then
        echo -n "twitch"
    elif [[ "$1" == *"youtube"* ]]; then
        echo -n "youtube"
    fi
}

function get_mpv_class_name() {
    case $1 in
        twitch|youtube) echo -n "mpv-$1";;
        *) log_error "unknown player $1" && exit 1;;
    esac
}

function handle_open_source() {
    case $2 in
        twitch) handle_open_twitch "$1";;
    esac
}

function handle_close_source() {
    case $1 in
        twitch) handle_close_twitch;;
    esac
}

function handle_open_twitch() {
    local chat_url
    chat_url="https://www.twitch.tv/popout/$(get_channel "$1")/chat?popout="
    "$ZDOTDIR"/scripts/default-browser/default-browser.sh "qutebrowser-twitch-chat" "$chat_url"
}

function handle_close_twitch() {
    hyprctl dispatch 'hl.dsp.window.close({ window = "class:qutebrowser-twitch-chat"})'  > >(log) 2> >(log_error) 2>&1
    hyprctl dispatch 'hl.dsp.window.close({ window = "class:mpv-twitch"})' > >(log) 2> >(log_error) 2>&1
}

function get_channel() {
    local channel
    channel=$(echo "$1" | sed -E 's~https?://(www\.)?twitch.tv/([^/?#]+)/?.*~\2~')
    if [[ -z "$channel" ]]; then
        show_error "Failed to parse Twitch channel"
        exit 1
    fi
    echo -n "$channel"
}

function wait_for_window() {
    local class="$1"
    local timeout=5
    local start
    start=$(date +%s)
    while true; do
        if hyprctl clients -j | jq -r '.[].class' | grep -Fx "$class" > >(log) 2> >(log_error); then
            return 0
        fi
        if (( $(date +%s) - start >= timeout )); then
            log "timeout waiting for $class"
            return 1
        fi
        sleep 0.05
    done
}

function play() {
    # https://www.reddit.com/r/youtubedl/comments/ou1mtk/ytdlp_how_i_use_cookies_from_browser/
    # create vivaldi profile and use --cookies-from-browser BROWSER[:PROFILE_NAME_OR_PATH]
    # --cookies-from-browser BROWSER[:PROFILE_NAME_OR_PATH]
    local url
    url=$1
    local source
    source=$2

    class=$(get_mpv_class_name "$source")
    force_close_previous_of_same_type $class
    mpv --force-window=immediate --wayland-app-id="$class" \
        "$url" > >(log) 2> >(log_error) &

    local mpv_pid=$!
    wait_for_window "$class"
    handle_open_source "$url" "$source"
    wait "$mpv_pid"
    status=$?
    if [[ $status -ne 0 ]]; then
        show_error "Playback failed"
    fi

    handle_close_source "$source"
}

function force_close_previous_of_same_type() {
    local class=$1
    case $class in
        mpv-twitch)
            handle_close_twitch;;
        mpv-youtube)
            hyprctl dispatch 'hl.dsp.window.close({ window = "class:mpv-youtube"})'  > >(log) 2> >(log_error) 2>&1
    esac
}


# qutebrowser passes TITLE URL; streamer selection now lives in the Twitch panel.
if [[ -z ${1:-} || -z ${2:-} ]]; then
    printf 'Usage: launcher.sh provider media TITLE URL (streamers: qs ipc call twitch open)\n' >&2
    exit 2
fi
url=$(clean "$2")
source=$(get_source "$url")
if [[ -z $source ]]; then
    show_error "Not a Twitch or YouTube URL"
    exit 1
fi
pause_player chromium.instance
play "$url" "$source"
