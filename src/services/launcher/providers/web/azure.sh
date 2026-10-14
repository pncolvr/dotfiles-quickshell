#!/usr/bin/env bash
set -euo pipefail

common_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../_common" && pwd)
cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/azure_${USER}"
container_name=${AZURE_PICKER_CONTAINER:-portkey}
container_image=${AZURE_PICKER_IMAGE:-portkey:latest}
source_dir=${AZURE_PICKER_SOURCE:-$HOME/Projects/helpers/portkey}
container_script=${AZURE_PICKER_SCRIPT:-/workspaces/scripts/azure/portkey/scripts/list-subs.sh}
credentials_volume=${AZURE_PICKER_VOLUME:-portkey-azure}
cache_temp=""
trap '[[ -z $cache_temp ]] || rm -f -- "$cache_temp"' EXIT

build_cache() {
    local running subscriptions
    local -a environment=()
    printf 'Building Azure subscription cache…\n' >&2
    running=$(podman container inspect --format '{{.State.Running}}' "$container_name" 2>/dev/null) || running=""
    case $running in
        true) ;;
        false) podman start "$container_name" >/dev/null ;;
        *)
            [[ -d $source_dir ]] || { printf 'Azure helper source directory is missing.\n' >&2; return 2; }
            if [[ -n ${AZURE_PICKER_ENV_FILE:-} ]]; then environment=(--env-file "$AZURE_PICKER_ENV_FILE"); fi
            podman run -d --name "$container_name" \
                -v "$credentials_volume:/home/vscode/.azure" \
                -v "$source_dir:/workspaces/scripts/azure/portkey" \
                -w /workspaces/scripts/azure/portkey \
                "${environment[@]}" --restart=unless-stopped \
                "$container_image" sleep infinity >/dev/null
            ;;
    esac
    # Device-code login instructions remain on stderr; subscription JSON goes
    # through validation. A picker subprocess does not need a terminal/TTY.
    subscriptions=$(podman exec "$container_name" "$container_script" | sed -n '/^[[:space:]]*\[/,$p' | tr -d '\r')
    umask 077
    mkdir -p -- "$(dirname -- "$cache_file")"
    cache_temp=$(mktemp "${cache_file}.XXXXXXXX")
    if ! jq -ce '
        if type != "array" or any(.[]; type != "object" or (.name | type) != "string"
            or (.id | type) != "string" or ((.tenantId // "") | type) != "string")
        then error("Invalid subscription list")
        else {prompt:"", action:"default", allowTyped:false, allowMultipleSelection:false, sort:true,
            items: map({title:.name, result:("https://portal.azure.com/#"
                + (if (.tenantId // "") != "" then "@" + .tenantId + "/" else "" end)
                + "resource/subscriptions/" + .id + "/resources")})}
        end
    ' <<< "$subscriptions" > "$cache_temp" 2>/dev/null; then
        printf 'Could not rebuild Azure subscription cache.\n' >&2
        return 2
    fi
    mv -f -- "$cache_temp" "$cache_file"
    cache_temp=""
    printf 'Azure subscription cache updated.\n' >&2
}

rebuild_cache=false
pick=false
for argument in "$@"; do
    case $argument in
        --rebuild-cache) rebuild_cache=true ;;
        --pick) pick=true ;;
        *) printf 'Usage: azure.sh [--rebuild-cache] [--pick]\n' >&2; exit 2 ;;
    esac
done
if $rebuild_cache; then build_cache; fi
if $pick; then
    [[ -f $cache_file ]] || build_cache
    bash "$common_dir/handle.sh" "$cache_file"
fi
