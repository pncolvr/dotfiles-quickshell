#!/usr/bin/env bash
# Public launcher and synchronous Bash picker. No global PATH changes.
set -euo pipefail
launcher_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_root=$(cd -- "$launcher_dir/../../.." && pwd)
qs_bin=${QS_PICKER_EXECUTABLE:-qs}
ipc() { "$qs_bin" ipc -p "${QS_PICKER_CONFIG:-$config_root}" "$@"; }
fail() { printf '%s\n' "$*" >&2; exit 2; }

if [[ ${1:-} == --bridge ]]; then
    action=${2:?}; request_dir=${3:?}
    runtime_root=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/quickshell-picker
    [[ -d $runtime_root && -O $runtime_root && ! -L $runtime_root ]]
    [[ $(stat -c %a -- "$runtime_root") == 700 ]]
    [[ $request_dir == "$runtime_root"/request.* && -d $request_dir && -O $request_dir && ! -L $request_dir ]]
    [[ $(realpath -e -- "$request_dir") == "$request_dir" ]]
    [[ -p $request_dir/reply && -O $request_dir/reply && ! -L $request_dir/reply ]]
    case $action in
        load)
            [[ -f $request_dir/request.json && ! -L $request_dir/request.json ]]
            [[ $(stat -c %s -- "$request_dir/request.json") -le 8000000 ]]
            jq -ce --arg directory "$request_dir" '
                if type != "object" or (.items | type) != "array"
                    or any(.items[]; type != "object" or (.title | type) != "string")
                then error("Invalid picker request") else . + {requestDirectory: $directory} end
            ' "$request_dir/request.json"
            ;;
        reply) timeout 2 bash -c 'cat > "$1/reply"' bash "$request_dir" ;;
        *) exit 2 ;;
    esac
    exit
fi

case ${1:-apps} in
    apps|clipboard) ipc call launcher "${1:-apps}"; exit ;;
    windows) ipc call launcher windows "${2:-all}"; exit ;;
    provider)
        name=${2:?Provider name required}; shift 2
        case $name in
            code|bookmarks|books|directories|media|power|screenshot|recording) provider="$launcher_dir/providers/$name.sh" ;;
            webapps|github|azure|n8n) provider="$launcher_dir/providers/web/$name.sh" ;;
            remotes) provider="$launcher_dir/providers/remotes/pick.sh" ;;
            *) fail "Unknown provider: $name" ;;
        esac
        [[ -f $provider ]] || fail "Provider script is missing: $provider"
        export QS_PICKER_CONFIG=${QS_PICKER_CONFIG:-$config_root}
        exec bash "$provider" "$@"
        ;;
    --json) input_file=${2:?JSON file required}; output_format=results ;;
    --json-response) input_file=${2:?JSON file required}; output_format=json ;;
    --dmenu) input_file=""; output_format=titles ;;
    *) fail 'Usage: launcher.sh apps|windows [all|current]|clipboard|provider NAME [ARGS...]|--json FILE|--json-response FILE|--dmenu [OPTIONS]' ;;
esac

runtime_root=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/quickshell-picker
umask 077
mkdir -p -- "$runtime_root"
[[ -O $runtime_root && ! -L $runtime_root && $(stat -c %a -- "$runtime_root") == 700 ]] || fail 'Picker runtime directory must be private and owned by you.'
request_dir=$(mktemp -d "$runtime_root/request.XXXXXXXX")
cleanup() {
    ipc call launcher cancel "$request_dir" >/dev/null 2>&1 || true
    rm -rf -- "$request_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
mkfifo -m 600 "$request_dir/reply"

if [[ -n $input_file ]]; then
    jq -ce 'if type == "object" and (.items | type) == "array" then . else error("Expected picker JSON") end' "$input_file" > "$request_dir/request.json"
else
    shift
    prompt=""; separator=$'\n'; multi=false; allow_typed=true; smart_case=true
    sort_results=false; fuzzy=false; custom_accept=false; layout=list; initial_query=""
    while (($#)); do
        case $1 in
            -dmenu) ;;
            -p|--prompt) prompt=${2?Prompt argument is required}; shift ;;
            -sep) separator=${2:?}; shift ;;
            -multi-select|--multi-select) multi=true ;;
            --grid) layout=grid ;;
            -case-smart) smart_case=true ;;
            -i) smart_case=false ;;
            -sort) sort_results=true ;;
            -no-custom|--no-custom) allow_typed=false ;;
            -sorting-method) [[ ${2:?} == fzf ]] && fuzzy=true; shift ;;
            -kb-accept-custom) [[ -z ${2-} ]] && allow_typed=false; shift ;;
            -kb-custom-1) [[ ${2:?} == Control+Return ]] || fail 'Only Control+Return custom acceptance is supported.'; custom_accept=true; shift ;;
            -filter) initial_query=${2-}; shift ;;
            -theme) [[ ${2:?} == *custom-row.rasi ]] && layout=grid; shift ;;
            -markup-rows) ;;
            -eh) shift ;;
            -show) fail 'Use launcher.sh apps or windows instead of rofi -show.' ;;
            *) fail "Unsupported picker option: $1" ;;
        esac
        shift
    done
    jq -Rsc --arg prompt "$prompt" --arg sep "$separator" --arg query "$initial_query" --arg layout "$layout" \
        --argjson multi "$multi" --argjson typed "$allow_typed" --argjson smart "$smart_case" \
        --argjson sort "$sort_results" --argjson fuzzy "$fuzzy" --argjson custom "$custom_accept" '
        {prompt:$prompt, allowMultipleSelection:$multi, allowTyped:$typed, smartCase:$smart,
         sort:$sort, fuzzy:$fuzzy, customAccept:$custom, layout:$layout, query:$query,
         items: (split($sep) | if .[-1] == "" then .[:-1] else . end | to_entries |
            map({id:(.key|tostring), title:.value, result:.value}))}
    ' > "$request_dir/request.json"
fi

# Open read/write before submitting so both endpoints are ready; only the helper writes.
exec {reply_fd}<>"$request_dir/reply"
ipc call launcher open "$request_dir" >/dev/null
picker_timeout=${QS_PICKER_TIMEOUT:-600}
[[ $picker_timeout =~ ^[1-9][0-9]*$ ]] || fail 'QS_PICKER_TIMEOUT must be a positive whole number of seconds.'
deadline=$((SECONDS + picker_timeout))
while ! IFS= read -r -t 1 response <&"$reply_fd"; do
    if ((SECONDS >= deadline)) || ! ipc call launcher alive >/dev/null 2>&1; then
        printf 'Picker timed out or the shell stopped.\n' >&2
        exit 2
    fi
done
exec {reply_fd}>&-
status=$(jq -er '.status' <<< "$response")
if [[ $status == cancelled ]]; then exit 1; fi
[[ $status == accepted ]] || fail 'The picker could not complete the request.'
case $output_format in
    json) printf '%s\n' "$response" ;;
    titles) jq -r '.items[].title' <<< "$response" ;;
    results) jq -r '.items[].result | if type == "string" then . else tojson end' <<< "$response" ;;
esac
exit "$(jq -r '.exitCode // 0' <<< "$response")"
