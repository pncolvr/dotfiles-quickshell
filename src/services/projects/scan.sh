#!/usr/bin/env bash
# Filesystem/Git boundary; JSON is stdout IPC only, never a project cache file.
set -euo pipefail
mode=${1:?}; shift
[[ $mode == scan ]]
# Discovery settings come from Config.qml; SSH host mappings come from its SSH config.
request=$(cat)
ssh_config=$(jq -r .sshConfig <<< "$request")
exclusions=$(jq -c .workspaceExclusions <<< "$request")
dotfiles=$(jq -r .dotfilesGitDirectory <<< "$request")
dotfiles_tree=$(jq -r .dotfilesWorkTree <<< "$request")
resolve_host() {
    local host=$1 settings hostname
    if [[ -f $ssh_config ]] && settings=$(ssh -G -F "$ssh_config" -- "$host" 2>/dev/null); then
        hostname=$(awk '$1 == "hostname" {print $2; exit}' <<< "$settings")
        printf '%s' "${hostname:-$host}"
    else
        printf '%s' "$host"
    fi
}
normalize_url() {
    local url=$1 host path mapped
    if [[ $url =~ ^git@([^:/]+)[:/](.+)$ ]]; then
        host=${BASH_REMATCH[1]} path=${BASH_REMATCH[2]}
        mapped=$(resolve_host "$host")
        url="https://$mapped/$path"
    elif [[ $url =~ ^ssh://([^@/]+@)?([^/:]+)(:[0-9]+)?/(.+)$ ]]; then
        host=${BASH_REMATCH[2]} path=${BASH_REMATCH[4]}
        mapped=$(resolve_host "$host")
        url="https://$mapped/$path"
    fi
    printf '%s' "${url%.git}"
}
scan_project() {
    local folder=$1 source=$2 category=$3 url='' workspace name
    if [[ -d $folder/.git || -f $folder/.git ]]; then
        url=$(git -C "$folder" remote get-url origin 2>/dev/null || true)
    fi
    # Only folders actually tracked by the bare dotfiles repository inherit its URL.
    if [[ -z $url && -d $dotfiles && $folder == "$dotfiles_tree/"* ]]; then
        if [[ -n $(git --git-dir="$dotfiles" --work-tree="$dotfiles_tree" ls-files -- "${folder#"$dotfiles_tree/"}/" 2>/dev/null) ]]; then
            url=$(git --git-dir="$dotfiles" --work-tree="$dotfiles_tree" remote get-url origin 2>/dev/null || true)
        fi
    fi
    [[ -z $url ]] || url=$(normalize_url "$url")
    local -a find_args=("$folder")
    while IFS= read -r pattern; do find_args+=(-path "$pattern" -prune -o); done < <(jq -r '.[]' <<< "$exclusions")
    find_args+=(-type f -name '*.code-workspace' -print0)
    # Capture errors: a failed subtree scan must not delete a previous snapshot.
    local listing
    listing=$(mktemp)
    if ! find "${find_args[@]}" > "$listing"; then rm -f "$listing"; return 1; fi
    local workspaces='[]'
    while IFS= read -r -d '' workspace; do
        workspace=$(realpath -e -- "$workspace")
        name=$(basename -- "$workspace" .code-workspace)
        workspaces=$(jq -c --arg path "$workspace" --arg name "$name" '. + [{path:$path,name:$name}]' <<< "$workspaces")
    done < "$listing"
    rm -f "$listing"
    jq -cn --arg path "$folder" --arg source "$source" --arg category "$category" --arg name "$(basename -- "$folder")" --arg url "$url" --argjson workspaces "$workspaces" \
        '{path:$path,source:$source,category:$category,name:$name,url:$url,workspaces:($workspaces | unique_by(.path) | sort_by(.name,.path))}'
}
results='[]'
while IFS= read -r source; do
    path=$(jq -r .path <<< "$source")
    kind=$(jq -r .kind <<< "$source")
    category=$(jq -r .category <<< "$source")
    error='' projects='[]'
    if [[ ! -d $path ]]; then
        error='Folder is missing or unavailable'
    else
        canonical=$(realpath -e -- "$path")
        folders=()
        if [[ $kind == root ]]; then
            listing=$(mktemp)
            if find "$canonical" -mindepth 1 -maxdepth 1 -type d -print0 > "$listing"; then
                while IFS= read -r -d '' folder; do folders+=("$folder"); done < "$listing"
            else error='Cannot read repositories root'; fi
            rm -f "$listing"
        else folders=("$canonical"); fi
        for folder in "${folders[@]}"; do
            if project=$(scan_project "$(realpath -e -- "$folder")" "$canonical" "$category"); then
                projects=$(jq -c --argjson project "$project" '. + [$project]' <<< "$projects")
            else error='Cannot read project workspaces'; break; fi
        done
        path=$canonical
    fi
    results=$(jq -c --arg path "$path" --arg kind "$kind" --arg category "$category" --arg error "$error" --argjson projects "$projects" \
        '. + [{path:$path,kind:$kind,category:$category,error:$error,projects:$projects}]' <<< "$results")
done < <(jq -c '.sources[]' <<< "$request")
jq -cn --argjson results "$results" '{sources:$results}'
