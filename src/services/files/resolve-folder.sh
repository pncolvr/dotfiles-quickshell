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
# Typed opening uses environment substitutions as data, never shell evaluation.
local_only=false
if [[ ${1:-} == --open ]]; then local_only=true; shift; fi
path=${1:?Folder path is required}
if $local_only; then
    expanded=''
    case $path in
        '~') expanded=$HOME; path='' ;;
        '~/'*) expanded="$HOME/"; path=${path:2} ;;
    esac
    variable_pattern='\$(\{([a-zA-Z_][a-zA-Z0-9_]*)\}|([a-zA-Z_][a-zA-Z0-9_]*))'
    while [[ $path =~ $variable_pattern ]]; do
        token=${BASH_REMATCH[0]}
        variable=${BASH_REMATCH[2]:-${BASH_REMATCH[3]}}
        [[ -v $variable ]] || { printf 'Environment variable is not set: %s.\n' "$variable" >&2; exit 1; }
        expanded+="${path%%"$token"*}${!variable}"
        path=${path#*"$token"}
    done
    path="$expanded$path"
    if [[ -z $path || $path =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
        printf 'Choose an existing local folder.\n' >&2; exit 1
    fi
    [[ $path == /* ]] || path="$HOME/$path"
fi
if [[ $path =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    name=${path%%:*}
    name=${name^}
else
    [[ $path == '~' ]] && path=$HOME
    [[ $path == '~/'* ]] && path="$HOME/${path:2}"
    IFS= read -r -d '' path < <(realpath -ez -- "$path" 2>/dev/null) \
        || { printf 'Choose an existing folder.\n' >&2; exit 1; }
    [[ -d $path ]] || { printf 'Choose an existing folder.\n' >&2; exit 1; }
    name=$(basename -- "$path")
fi
jq -cn --arg path "$path" --arg name "$name" '{path:$path,name:$name}'
