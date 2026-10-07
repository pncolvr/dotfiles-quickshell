#!/usr/bin/env bash

source "$(dirname -- "${BASH_SOURCE[0]}")/_common/utils.sh"

OUTPUT_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/books_${USER}"
TEMPLATE_JSON='{
    "prompt": "",
    "action": "output",
    "allowTyped": false,
    "allowMultipleSelection": false,
    "sort": true
}'

function get_title() {
    local file="$1"
    local filename
    local ext
    ext="${file##*.}"
    ext="${ext,,}"
    local title=""
    if [[ "$ext" == "pdf" ]]; then
        title=$(pdfinfo "$file" 2>/dev/null | sed -n 's/^Title:[[:space:]]*//p' | head -n1)
    elif [[ "$ext" == "epub" ]]; then
        title=$(exiftool -Title "$file" 2>/dev/null | sed -n 's/^Title[[:space:]]*:[[:space:]]*//p' | head -n1)
    fi
    title=$(echo "$title" | sed 's/^ *//;s/ *$//;s/  */ /g')
    if [[ -z "$title" ]]; then
        filename="${file##*/}"
        title="${filename%.*}"
    fi
    title="${title} (${ext})"
    echo "$title"
}

function build_cache() {
    echo "Building cache..."
    mapfile -t files < <(find "$HOME/Books" -type f \( -iname '*.pdf' -o -iname '*.epub' \))
    json_items=()
    for file in "${files[@]}"; do
        title=$(get_title "$file")
        json_items+=("$(jq -cn --arg title "$title" --arg result "$file" '{title: $title, result: $result}')")
    done

    items_json=$(printf '%s\n' "${json_items[@]}" | jq -s '.')
    final_json=$(jq -n --argjson items "$items_json" --argjson template "$TEMPLATE_JSON" '$template + {items: $items}')

    echo "$final_json" > "$OUTPUT_FILE"
    echo "Cache saved: $OUTPUT_FILE"
}


rebuild_cache=false
pick=false

for arg in "$@"; do
    case "$arg" in
        --rebuild-cache)
            rebuild_cache=true
            ;;
        --pick)
            pick=true
            ;;
    esac
done

if $rebuild_cache; then
    build_cache
fi

if $pick; then
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        build_cache
    fi

    chosen=$(bash "$PICKER_HANDLER" "$OUTPUT_FILE")
    if [[ -n $chosen ]]; then
        zathura "$chosen" > /dev/null 2>&1 & disown
    fi
fi
