#!/usr/bin/env bash

WORKSPACE=$(echo "${BASH_SOURCE[0]:-0}" | xargs realpath | xargs dirname | xargs dirname)/_common

CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/azure_${USER}"
TEMPLATE_JSON='{
    "prompt": "",
    "action": "default",
    "allowTyped": false,
    "allowMultipleSelection": false,
    "sort": true
}'

build_cache() {
    echo "Building cache..."
    podman run -d --replace --name portkey \
        -v portkey-azure:/home/vscode/.azure \
        -v "/home/pncolvr/Projects/helpers/portkey":/workspaces/scripts/azure/portkey \
        -w /workspaces/scripts/azure/portkey \
        --restart=unless-stopped \
        portkey:latest sleep infinity

    json_output=$(podman exec -it azure-tools /workspaces/scripts/azure/updateip/scripts/list-subs.sh | sed -n '/^\[/,$p' | tr -d '\r')
    items_json=$(jq 'map({title: .name, result: ("https://portal.azure.com/#@teambizdocs.onmicrosoft.com/resource/subscriptions/" + .id + "/resources")})' <<< "$json_output")
    final_json=$(jq -n --argjson items "$items_json" --argjson template "$TEMPLATE_JSON" '$template + {items: $items}')

    echo "$final_json" > "$CACHE_FILE"
    echo "Cache saved: $CACHE_FILE"
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
    if [[ ! -f "$CACHE_FILE" ]]; then
        build_cache
    fi

    "$WORKSPACE"/handle.sh "$CACHE_FILE"
fi