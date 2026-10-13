#!/usr/bin/env bash
# Shared picker functions, reused from the former Rofi and Hyprland helpers.
_picker_common_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PICKER_LAUNCHER="$_picker_common_dir/../../launcher.sh"
PICKER_HANDLER="$_picker_common_dir/handle.sh"
ZDOTDIR=${ZDOTDIR:-$HOME/.config/zsh}

function open_url() {
    "$ZDOTDIR/scripts/default-browser/default-browser.sh" "$@"
}

function get_temp_dir() {
    printf '%s\n' "${XDG_RUNTIME_DIR:-/tmp}"
}

function get_temp_file_named() {
    printf '%s/%s_%s\n' "$(get_temp_dir)" "$1" "$(id -u)"
}

function get_env_file() {
    local path=$1 filename
    filename=$(basename -- "$path")
    printf '%s/%s.env\n' "$(dirname -- "$path")" "${filename%.*}"
}

function get_ignored_category() {
    local status working_state=${WORKING_STATE_NAME:-work}
    status=$("$ZDOTDIR/scripts/status/manager.sh" --get)
    if [[ $status != "$working_state" ]]; then printf '%s' "$working_state"; fi
    return 0
}

function open_file_explorer() {
    local file=$1
    if [[ -f $file ]]; then
        dbus-send --type=method_call --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:"file://$file" string:""
    elif [[ -d $file ]]; then
        xdg-open "$file"
    else
        pcmanfm-qt "$file"
    fi
    hyprctl dispatch 'hl.dsp.focus({ window = "class:pcmanfm-qt" })'
}

if [[ -f $_picker_common_dir/utils.env ]]; then source "$_picker_common_dir/utils.env"; fi
