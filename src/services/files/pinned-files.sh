#!/usr/bin/env bash
# Report deleted pinned paths without reading document contents.
set -euo pipefail

# A failed existence check under an inaccessible directory does not prove deletion.
can_check_path() {
    local remaining=${1#/} directory=/ component
    [[ -x $directory ]] || return 1
    while [[ $remaining == */* ]]; do
        component=${remaining%%/*}
        remaining=${remaining#*/}
        [[ -n $component ]] || continue
        directory=${directory%/}/$component
        if [[ ! -e $directory && ! -L $directory ]]; then return 0; fi
        [[ -d $directory && -x $directory ]] || return 1
    done
}

# Validate all input before checking paths; NUL records preserve filename whitespace.
records=$(jq -ce 'if type == "array" and all(.[];
    type == "object" and (.path | type) == "string" and (.path | startswith("/"))
    and (.path | contains("\u0000") | not) and (.uri | type) == "string"
    and (.uri | contains("\u0000") | not))
    then . else error("Invalid pinned files") end')
while IFS= read -r -d '' uri && IFS= read -r -d '' path; do
    if [[ ! -e $path ]]; then
        # Resolve symlinks so inaccessible target parents cannot look like deletion.
        IFS= read -r -d '' resolved < <(readlink -mz -- "$path") || continue
        if can_check_path "$resolved"; then printf '%s\0' "$uri"; fi
    fi
done < <(jq -jr '.[] | .uri, "\u0000", .path, "\u0000"' <<< "$records") |
    jq -Rs 'split("\u0000")[:-1]'
