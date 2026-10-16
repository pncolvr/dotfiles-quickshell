#!/usr/bin/env bash
# Read-only work detection using private rules supplied by Quickshell.
set -euo pipefail
# Private rules arrive over stdin, not config/state files.
payload=$(cat)
jq -e '(.workDirectories|type=="array" and all(.[];type=="string")) and (.processes|type=="array" and all(.[];type=="string"))' <<< "$payload" >/dev/null
mapfile -d '' -t work_directories < <(jq -j '.workDirectories[] | ., "\u0000"' <<< "$payload")
mapfile -d '' -t patterns < <(jq -j '.processes[] | ., "\u0000"' <<< "$payload")
fields=()
errors=()
for pattern in "${patterns[@]}"; do
    if processes=$(pgrep -u "$USER" -x -l -- "$pattern"); then
        while IFS=' ' read -r pid name; do
            [[ $pid =~ ^[0-9]+$ && -n $name ]] || continue
            executable=$(readlink -- "/proc/$pid/exe" 2>/dev/null || true)
            fields+=("process" "$name" "$executable")
        done <<< "$processes"
    else
        result=$?
        (( result == 1 )) || errors+=("Could not check configured process: $pattern")
    fi
done
if ((${#work_directories[@]})); then
    if command -v lsof >/dev/null 2>&1; then
        report=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/status-detection.XXXXXX")
        trap 'rm -f -- "$report"' EXIT
        result=0
        lsof -n -P -a -u "$USER" -F0pcfn > "$report" 2>/dev/null || result=$?
        if (( result > 1 )); then errors+=("Could not inspect open work files."); fi
        name= descriptor=
        while IFS= read -r -d '' field; do
            field=${field#$'\n'}
            case ${field:0:1} in
                p) name=; descriptor= ;;
                c) name=${field:1} ;;
                f) descriptor=${field:1} ;;
                n)
                    path=${field:1}
                    [[ -n $name ]] || continue
                    for work_directory in "${work_directories[@]}"; do
                        [[ $path == "$work_directory" || $path == "${work_directory%/}/"* ]] || continue
                        kind=file
                        [[ $descriptor != cwd ]] || kind=directory
                        fields+=("$kind" "$name" "$path")
                        break
                    done
                    ;;
            esac
        done < "$report"
    else errors+=("Open work-file detection requires lsof."); fi
fi
matches=$( { if ((${#fields[@]})); then printf '%s\0' "${fields[@]}"; fi; } | jq -Rs '
    split("\u0000") | if length == 1 and .[0] == "" then [] else .[:-1] end
    | . as $fields | [range(0; length; 3) as $i | {method:$fields[$i], name:$fields[$i+1], path:$fields[$i+2]}]
    | group_by(.name) | map({name:.[0].name, methods:map(.method)|unique, paths:map(.path)|map(select(length > 0))|unique})')
error_report=$( { if ((${#errors[@]})); then printf '%s\0' "${errors[@]}"; fi; } | jq -Rs 'split("\u0000") | if length == 1 and .[0] == "" then [] else .[:-1] end')
jq -n --argjson matches "$matches" --argjson errors "$error_report" \
    '{matches:$matches,errors:$errors}'
