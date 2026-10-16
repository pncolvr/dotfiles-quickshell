#!/usr/bin/env bash
# Public launcher and synchronous Bash picker. No global PATH changes.
set -Eeuo pipefail
# Reserve exit 1 for an explicit cancelled reply. Failed IPC/JSON commands must
# not be mistaken for user cancellation by password-manager callers.
trap 'exit 2' ERR
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
                then error("Invalid picker request")
                elif .markupRows == true then
                    .items |= map(. + {originalTitle: .title, result: (.result // .title),
                        title: (.title | gsub("<[^>]*>"; "") | gsub("^\\s+|\\s+$"; ""))})
                    | . + {requestDirectory: $directory}
                else . + {requestDirectory: $directory} end
            ' "$request_dir/request.json"
            ;;
        watch) exec bash "$launcher_dir/secret_prompt.sh" --check-owner "$request_dir" ;;
        reply) timeout 2 bash -c 'cat > "$1/reply"' bash "$request_dir" ;;
        *) exit 2 ;;
    esac
    exit
fi

if [[ ${1:-} == --secret ]]; then
    shift
    exec bash "$launcher_dir/secret_prompt.sh" "$@"
fi

validate_provider_config() {
    jq -ce '
        if type == "object"
            and keys == ["SCREENSHOT_FOLDER","VIDEOS_FOLDER","WALLPAPER_DIRECTORY","WALLPAPER_STATE_DIRECTORY","WORKING_STATE_NAME","WORK_MODE_ENABLED"]
            and (.WORK_MODE_ENABLED == "true" or .WORK_MODE_ENABLED == "false")
            and all(.[]; type == "string" and length > 0 and (contains("\u0000") | not))
        then . else error("Invalid provider configuration") end'
}
if [[ ${1:-} == --provider-config ]]; then
    if provider_config=$(ipc call launcher providerConfig 2>/dev/null); then
        validate_provider_config <<< "$provider_config"
        exit
    fi
fi

case ${1:-apps} in
    apps|clipboard|projects|directories|webapps|remotes|n8n) ipc call launcher "${1:-apps}"; exit ;;
    windows) ipc call launcher windows "${2:-all}"; exit ;;
    expose) ipc call launcher expose "${2:-current}"; exit ;;
    provider)
        name=${2:?Provider name required}; shift 2
        case $name in
            power) if (($# == 0)); then ipc call launcher power; exit; fi ;;
            bookmarks) ipc call launcher bookmarks; exit ;;
            code) ipc call launcher projects; exit ;;
            github) ipc call launcher projectUrls; exit ;;
            directories) ipc call launcher directories; exit ;;
            webapps) ipc call launcher webapps; exit ;;
        esac
        case $name in
            power|screenshot|recording|encode-qrcode|wallpaper) provider="$launcher_dir/providers/$name.sh" ;;
            n8n) ipc call launcher n8n; exit ;;
            remotes) ipc call launcher remotes; exit ;;
            *) fail "Unknown provider: $name" ;;
        esac
        [[ -f $provider ]] || fail "Provider script is missing: $provider"
        export QS_PICKER_CONFIG=${QS_PICKER_CONFIG:-$config_root}
        exec bash "$provider" "$@"
        ;;
    --json) input_file=${2:?JSON file required}; output_format=results ;;
    --json-response) input_file=${2:?JSON file required}; output_format=json ;;
    --dmenu) input_file=""; output_format=titles ;;
    --provider-config) input_file=""; output_format=provider-config ;;
    *) fail 'Usage: launcher.sh apps|projects|directories|windows [all|current]|expose [all|current]|clipboard|provider NAME [ARGS...]|--provider-config|--json FILE|--json-response FILE|--dmenu [OPTIONS]' ;;
esac

runtime_root=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/quickshell-picker
umask 077
mkdir -p -- "$runtime_root"
[[ -O $runtime_root && ! -L $runtime_root && $(stat -c %a -- "$runtime_root") == 700 ]] || fail 'Picker runtime directory must be private and owned by you.'
request_dir=$(mktemp -d "$runtime_root/request.XXXXXXXX")
cleanup() {
    if [[ -n ${config_pid:-} ]]; then
        kill -TERM "$config_pid" 2>/dev/null || true
        wait "$config_pid" 2>/dev/null || true
    fi
    if [[ $output_format != provider-config ]]; then
        ipc call launcher cancel "$request_dir" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$request_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
mkfifo -m 600 "$request_dir/reply"

if [[ $output_format == provider-config ]]; then
    exec {reply_fd}<>"$request_dir/reply"
    QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1 QS_NO_RELOAD_POPUP=1 \
        QS_PROVIDER_CONFIG_REQUEST="$request_dir" \
        timeout 8 "$qs_bin" -p "${QS_PICKER_CONFIG:-$config_root}/provider-config.qml" \
        > "$request_dir/export.log" 2>&1 & config_pid=$!
    config_deadline=$((SECONDS + 5))
    while ! IFS= read -r -t 0.1 provider_config <&"$reply_fd"; do
        ((SECONDS < config_deadline)) && kill -0 "$config_pid" 2>/dev/null \
            || fail 'Could not read offline provider configuration.'
    done
    wait "$config_pid" || fail 'Could not export provider configuration.'
    config_pid=''
    exec {reply_fd}>&-
    validate_provider_config <<< "$provider_config"
    exit
fi

if [[ -n $input_file ]]; then
    jq -ce 'if type == "object" and (.items | type) == "array" then . else error("Expected picker JSON") end' "$input_file" > "$request_dir/request.json"
else
    shift
    prompt=""; separator=$'\n'; multi=false; allow_typed=true
    sort_results=false; custom_accept=false; layout=list; initial_query=""; selection_key=""; markup_rows=false
    while (($#)); do
        case $1 in
            -dmenu) ;;
            -p|--prompt) prompt=${2?Prompt argument is required}; shift ;;
            -sep) separator=${2:?}; shift ;;
            -multi-select|--multi-select) multi=true ;;
            --grid) layout=grid ;;
            --keep-pointer) ;; # Compatibility: every launcher now preserves the pointer.
            -case-smart|-i) ;; # Legacy options cannot override Config.qml search settings.
            -sort) sort_results=true ;;
            -no-custom|--no-custom) allow_typed=false ;;
            -sorting-method) : "${2:?}"; shift ;; # Search method belongs to Config.qml.
            -kb-accept-custom) [[ -z ${2-} ]] && allow_typed=false; shift ;;
            -kb-custom-1) [[ ${2:?} == Control+Return ]] || fail 'Only Control+Return custom acceptance is supported.'; custom_accept=true; shift ;;
            -filter) initial_query=${2-}; shift ;;
            --selection-key) selection_key=${2:?Selection key required}; shift ;;
            -theme) [[ ${2:?} == *custom-row.rasi ]] && layout=grid; shift ;;
            -markup-rows) markup_rows=true ;;
            -eh) shift ;;
            -show) fail 'Use launcher.sh apps or windows instead of rofi -show.' ;;
            *) fail "Unsupported picker option: $1" ;;
        esac
        shift
    done
    jq -Rsc --arg prompt "$prompt" --arg sep "$separator" --arg query "$initial_query" --arg layout "$layout" --arg selectionKey "$selection_key" \
        --argjson multi "$multi" --argjson typed "$allow_typed" \
        --argjson sort "$sort_results" --argjson custom "$custom_accept" --argjson markup "$markup_rows" '
        {prompt:$prompt, allowMultipleSelection:$multi, allowTyped:$typed,
         sort:$sort, customAccept:$custom, layout:$layout, query:$query, selectionKey:$selectionKey, markupRows:$markup,
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
    titles) jq -r '.items[] | .originalTitle // .title' <<< "$response" ;;
    results) jq -r '.items[].result | if type == "string" then . else tojson end' <<< "$response" ;;
esac
exit "$(jq -r '.exitCode // 0' <<< "$response")"
