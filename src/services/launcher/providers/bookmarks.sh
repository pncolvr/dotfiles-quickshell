#!/usr/bin/env bash

WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$WORKSPACE"/_common/utils.sh

TEMPLATE_JSON='{
    "prompt": "",
    "action": "default",
    "allowTyped": true,
    "allowMultipleSelection": true,
    "sort": true
}'

json_items=()
while read -r url name; do
    json_items+=("$(jq -cn --arg title "$name" --arg result "$url" '{title: $title, result: $result}')")
done < "$HOME"/.config/qutebrowser/bookmarks/urls

items_json=$(printf '%s\n' "${json_items[@]}" | jq -s '.')
final_json=$(jq -n --argjson items "$items_json" --argjson template "$TEMPLATE_JSON" '$template + {items: $items}')

bookmarks_file=$(get_temp_file_named "qutebrowser_bookmarks")
echo "$final_json" > "$bookmarks_file"

bash "$PICKER_HANDLER" "$bookmarks_file"
