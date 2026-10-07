#!/usr/bin/env bash
# Existing providers keep their JSON and browser/action helpers; Quickshell owns selection.
set -eo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/utils.sh"
FILE=${1:?Picker JSON is required}
picker=$PICKER_LAUNCHER
action=$(jq -r '.action // "default"' "$FILE")
count=$(jq -r '.items | length' "$FILE")
if [[ $count == 0 ]]; then exit 0; fi
if [[ $count == 1 ]]; then
    selected=$(jq -r '.items[0].result | if type == "string" then . else tojson end' "$FILE")
else
    selected=$(bash "$picker" --json "$FILE") || exit "$?"
fi
while IFS= read -r result; do
    [[ -n $result ]] || continue
    case $action in
        output) printf '%s\n' "$result" ;;
        *) open_url "$result" ;;
    esac
done <<< "$selected"
