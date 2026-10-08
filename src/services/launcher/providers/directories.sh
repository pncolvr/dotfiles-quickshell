#!/usr/bin/env bash

WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$WORKSPACE"/_common/utils.sh

FILE="${BASH_SOURCE[0]%.*}.json"
STATUS=$($ZDOTDIR/scripts/status/manager.sh --get)

if [[ "$STATUS" == "work" ]]; then
    TEMP_FILE=$(get_temp_file_named "pick_combined")
    jq '{
        prompt,
        action,
        allowTyped,
        sort,
        items: (.items + (.extraItems // []))
    }' "$FILE" > "$TEMP_FILE"
    FILE="$TEMP_FILE"
fi

chosen=$(bash "$PICKER_HANDLER" "$FILE")

if [[ -n $chosen ]]; then
    read -r type path < <(jq -r '[.type, (.path // "")] | @tsv' <<< "$chosen")

    if [[ $type == "directory" ]]; then
        [[ $path == ~* ]] && path="${path/#\~/$HOME}"
        # path="${path//\$HOME/$HOME}"
        path="$(realpath "$path")"
    fi

    open_file_explorer "$path"
fi
