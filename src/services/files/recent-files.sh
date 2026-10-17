#!/usr/bin/env bash
# Read the desktop's XBEL history without changing it.
set -euo pipefail

fail() {
    printf '{"files":[],"error":"%s"}\n' "$1"
    exit "${2:-1}"
}
source_path="${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"
max_items=20
max_days=7
while (($#)); do
    case "$1" in
        --source|--max-items|--max-days)
            (($# >= 2)) || fail 'files.recent.errors.missingOption' 2
            case "$1" in
                --source) source_path=$2 ;;
                --max-items) max_items=$2 ;;
                --max-days) max_days=$2 ;;
            esac
            shift 2 ;;
        *) fail 'files.recent.errors.unknownOption' 2 ;;
    esac
done
for limit in "$max_items" "$max_days"; do
    [[ $limit =~ ^[0-9]{1,10}$ ]] && ((10#$limit <= 2147483647)) \
        || fail 'files.recent.errors.limits' 2
done
max_items=$((10#$max_items))
max_days=$((10#$max_days))
for dependency in jq xsltproc date; do
    command -v "$dependency" >/dev/null || fail 'files.recent.errors.dependencies'
done
if [[ ! -e $source_path ]]; then
    printf '{"files":[],"error":""}\n'
    exit 0
fi
[[ -f $source_path && -r $source_path ]] || fail 'files.recent.errors.read'

helper_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
umask 077
work_dir=$(mktemp -d) || fail 'files.recent.errors.prepare'
trap 'rm -rf -- "$work_dir"' EXIT
# Read one snapshot: application writes during filtering cannot change the input.
cp -- "$source_path" "$work_dir/history.xbel" || fail 'files.recent.errors.read'
# The desktop bookmark format does not need DTDs or custom entities.
if LC_ALL=C grep -aqE '<!DOCTYPE|<!ENTITY' "$work_dir/history.xbel"; then
    fail 'files.recent.errors.read'
fi
xsltproc --nonet --novalid --nowrite --nomkdir "$helper_dir/recent-files.xsl" \
    "$work_dir/history.xbel" > "$work_dir/records" 2>/dev/null \
    || fail 'files.recent.errors.read'
now=$(date +%s)
cutoff=0
if ((max_days > 0)); then cutoff=$((now - max_days * 86400)); fi

# Decode URI bytes without command substitution, which strips trailing newlines.
decode_path() {
    local encoded=$1 byte hex
    decoded_path=''
    while [[ $encoded == *%* ]]; do
        decoded_path+=${encoded%%\%*}
        encoded=${encoded#*%}
        hex=${encoded:0:2}
        [[ $hex =~ ^[[:xdigit:]]{2}$ && $hex != 00 ]] || return 1
        printf -v byte '%b' "\\x$hex"
        decoded_path+=$byte
        encoded=${encoded:2}
    done
    decoded_path+=$encoded
}

: > "$work_dir/files"
while IFS= read -r record; do
    # Preserve empty attributes; IFS tab splitting would collapse those fields.
    fields=()
    for ((index = 0; index < 4; index++)); do
        fields+=("${record%%$'\t'*}")
        record=${record#*$'\t'}
    done
    fields+=("$record")
    case "${fields[0]}" in
        file:///*) encoded_path=${fields[0]#file://} ;;
        file://localhost/*) encoded_path=${fields[0]#file://localhost} ;;
        *) continue ;;
    esac
    decode_path "$encoded_path" || continue
    [[ -f $decoded_path && -r $decoded_path ]] || continue
    used_at=0
    for stamp in "${fields[@]:1:3}"; do
        [[ -n $stamp ]] || continue
        seconds=$(date -d "$stamp" +%s 2>/dev/null) || continue
        if ((seconds > used_at)); then used_at=$seconds; fi
    done
    ((used_at > 0 && used_at >= cutoff)) || continue
    case "${fields[4]}" in
        image/*) icon=image-x-generic ;;
        audio/*) icon=audio-x-generic ;;
        video/*) icon=video-x-generic ;;
        application/pdf) icon=application-pdf ;;
        application/*zip*|application/*compressed*|application/x-tar) icon=package-x-generic ;;
        *) icon=text-x-generic ;;
    esac
    # NUL delimiters preserve tabs/newlines in real filenames. jq encodes the URI.
    printf '%s\0%s\0%s\0' "$decoded_path" "$((used_at * 1000))" "$icon" >> "$work_dir/files"
done < "$work_dir/records"

jq -L "$helper_dir" -Rs --argjson max "$max_items" '
    include "natural-sort";
    include "file-records";
    split("\u0000")[:-1] as $fields |
    [range(0; $fields | length; 3) as $i |
        ($fields[$i] | file_record) +
        {usedAt: ($fields[$i + 1] | tonumber), icon: $fields[$i + 2]}] |
    group_by(.uri) | map(max_by(.usedAt)) | sort_by([-.usedAt, (.name | natural_name_key), .path]) |
    (if $max > 0 then .[:$max] else . end) | {files: ., error: ""}
' "$work_dir/files" || fail 'files.recent.errors.prepare'
