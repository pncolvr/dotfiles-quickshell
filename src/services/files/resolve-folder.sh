#!/usr/bin/env bash
# Resolve local folders; virtual file-manager locations keep their URI.
set -euo pipefail
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
