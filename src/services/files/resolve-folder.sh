#!/usr/bin/env bash
# Resolve local folders; virtual file-manager locations keep their URI.
set -euo pipefail
# Read-only batch checks shared by Manage lists and backup import. Never scan,
# create, mount or remove paths. NUL records preserve whitespace in filenames.
if [[ ${1:-} == --check ]]; then
    records=$(jq -ce 'select(type == "array" and all(.[];
        type == "object" and (.path | type == "string" and (contains("\u0000") | not))
        and (.kind == "directory" or .kind == "file")))')
    while IFS= read -r -d '' path && IFS= read -r -d '' kind; do
        status=available
        if [[ $path =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
            status=unchecked
        elif [[ $path != /* ]]; then
            status=unavailable
        elif [[ $kind == directory ]]; then
            if [[ ! -d $path || ! -r $path || ! -x $path ]]; then
                status=unavailable
            fi
        elif [[ ! -f $path || ! -r $path ]]; then
            status=unavailable
        fi
        printf '%s\0' "$status"
    done < <(printf '%s' "$records" | jq -jr '.[] | .path, "\u0000", .kind, "\u0000"') |
        jq -Rs --slurpfile records <(printf '%s' "$records") '
            split("\u0000")[:-1] as $states | $records[0] | to_entries | map(.value + {status:$states[.key]} |
                .message = (if .status == "available" then "" elif .status == "unchecked" then "Location not checked"
                    elif .kind == "file" then "Workspace file missing or unavailable" else "Folder missing or unavailable" end))'
    exit 0
fi
path=${1:?Folder path is required}
if [[ $path =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    name=${path%%:*}
    name=${name^}
else
    [[ $path == '~' ]] && path=$HOME
    [[ $path == '~/'* ]] && path="$HOME/${path:2}"
    path=$(realpath -e -- "$path")
    [[ -d $path ]] || { printf 'Choose an existing folder.\n' >&2; exit 1; }
    name=$(basename -- "$path")
fi
jq -cn --arg path "$path" --arg name "$name" '{path:$path,name:$name}'
