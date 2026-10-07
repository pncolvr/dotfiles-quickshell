#!/usr/bin/env bash
# List all immediate files and readable directories in a folder, newest first.
set -euo pipefail

fail() { printf '{"files":[],"error":"%s"}\n' "$1"; exit "${2:-1}"; }
folder=''
while (($#)); do
    case "$1" in
        --folder)
            (($# >= 2)) || fail 'Missing folder option value.' 2
            folder=$2
            shift 2 ;;
        *) fail 'Unknown folder option.' 2 ;;
    esac
done
for dependency in find stat jq; do
    command -v "$dependency" >/dev/null || fail 'Folder files require GNU findutils, coreutils, and jq.'
done
case "$folder" in
    '~') folder=$HOME ;;
    '~/'*) folder="$HOME/${folder:2}" ;;
esac
[[ -n $folder && -d $folder && -r $folder && -x $folder ]] || fail 'Choose an existing, readable folder.'
# Canonicalize aliases, including symlinks, without stripping filename newlines.
folder=$(cd -P -- "$folder" && printf '%s/' "$PWD") || fail 'Could not open this folder.'
folder=${folder%/}
umask 077
helper_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
work_dir=$(mktemp -d) || fail 'Could not prepare the folder list.'
trap 'rm -rf -- "$work_dir"' EXIT
find -L "$folder" -mindepth 1 -maxdepth 1 \( -type f -o \( -type d -executable \) \) -readable -print0 \
    > "$work_dir/paths" 2>/dev/null || fail 'Could not read this folder.'
: > "$work_dir/files"
while IFS= read -r -d '' path; do
    timestamps=$(stat -L --printf '%Y %W' -- "$path" 2>/dev/null) || continue
    read -r modified created <<< "$timestamps"
    icon=text-x-generic
    is_directory=false
    if [[ -d $path ]]; then
        is_directory=true
        icon=inode-directory
    else
        case "${path,,}" in
            *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.avif) icon=image-x-generic ;;
            *.mp3|*.flac|*.ogg|*.wav|*.m4a|*.opus) icon=audio-x-generic ;;
            *.mp4|*.mkv|*.webm|*.mov|*.avi) icon=video-x-generic ;;
            *.pdf) icon=application-pdf ;;
            *.zip|*.gz|*.xz|*.bz2|*.7z|*.tar|*.zst) icon=package-x-generic ;;
        esac
    fi
    printf '%s\0%s\0%s\0%s\0%s\0' "$path" "$((modified * 1000))" "$((created * 1000))" "$icon" "$is_directory" >> "$work_dir/files"
done < "$work_dir/paths"
jq -L "$helper_dir" -Rs --arg folder "$folder" '
    include "natural-sort";
    split("\u0000")[:-1] as $fields |
    [range(0; $fields | length; 5) as $i |
        $fields[$i] as $path | ($path | split("/")) as $parts |
        ($fields[$i + 1] | tonumber) as $modified |
        ($fields[$i + 2] | tonumber) as $created |
        ($created > 0 and $created > $modified) as $useCreated |
        {path: $path, name: $parts[-1], directory: $folder,
         uri: ("file://" + ($parts | map(@uri) | join("/"))),
         modifiedAt: $modified, createdAt: $created,
         usedAt: (if $useCreated then $created else $modified end),
         timeKind: (if $useCreated then "created" else "modified" end), icon: $fields[$i + 3],
         isDirectory: ($fields[$i + 4] == "true")}] |
    sort_by([(if .isDirectory then 0 else 1 end), -.usedAt, (.name | natural_name_key), .path]) |
    {files: ., folder: $folder, error: ""}
' "$work_dir/files" || fail 'Could not prepare the folder list.'
