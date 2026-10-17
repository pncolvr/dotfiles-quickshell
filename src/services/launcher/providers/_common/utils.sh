#!/usr/bin/env bash
# Shared provider Config export and completed-file reveal helpers.
_picker_common_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PICKER_LAUNCHER="$_picker_common_dir/../../launcher.sh"
function load_provider_config() {
    local settings
    local -a assignments
    settings=$(bash "$PICKER_LAUNCHER" --provider-config) || return 2
    mapfile -d '' -t assignments < <(jq -j 'to_entries[] | (.key + "=" + .value), "\u0000"' <<< "$settings")
    export -- "${assignments[@]}"
}

function open_file_explorer() {
    local file=$1 uri
    if [[ -f $file ]]; then
        # Encode path segments, retaining separators; commas also delimit dbus-send arrays.
        uri=$(jq -nr --arg path "$file" '"file://" + ($path | split("/") | map(@uri) | join("/"))') || return
        dbus-send --type=method_call --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:"$uri" string:""
    elif [[ -d $file ]]; then
        xdg-open "$file"
    else
        pcmanfm-qt "$file"
    fi
    hyprctl dispatch 'hl.dsp.focus({ window = "class:pcmanfm-qt" })'
}
