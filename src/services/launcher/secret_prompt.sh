#!/usr/bin/env bash
# Only public prompt metadata is saved. Secret replies remain in memory/pipes.
set +x
set -euo pipefail
export LC_ALL=C
umask 077

private_directory() {
    [[ -d $1 && -O $1 && ! -L $1 && $(stat -c %a -- "$1" 2>/dev/null) == 700 ]]
}
process_start() {
    local record
    IFS= read -r record < "/proc/$1/stat" || return 1
    # The comm field can contain spaces and parentheses; strip through its last ).
    record=${record##*) }
    local -a fields
    read -r -a fields <<< "$record"
    [[ ${fields[19]:-} =~ ^[0-9]+$ ]] || return 1
    printf '%s' "${fields[19]}"
}
check_owner() {
    local directory=$1 runtime_root=${XDG_RUNTIME_DIR:?}/quickshell-picker pid start current
    private_directory "$runtime_root" && private_directory "$directory" || return 1
    [[ ${directory%/*} == "$runtime_root" && ${directory##*/} == request.*
        && $(realpath -e -- "$directory") == "$directory"
        && -f $directory/request.json && ! -L $directory/request.json ]] || return 1
    [[ $(stat -c %s -- "$directory/request.json") -le 16384 ]] || return 1
    jq -e 'type == "object" and .kind == "secret" and
        (.ownerPid | type == "number" and . > 0 and . == floor) and
        (.ownerStart | type == "string" and test("^[0-9]+$"))' "$directory/request.json" >/dev/null 2>&1 || return 1
    pid=$(jq -r '.ownerPid' "$directory/request.json")
    start=$(jq -r '.ownerStart' "$directory/request.json")
    if current=$(process_start "$pid" 2>/dev/null) && [[ $current == "$start" ]]; then return 0; fi
    rm -rf -- "$directory"
    return 1
}

prompt=Secret description='' error='' format=raw
while (($#)); do
    case $1 in
        --prompt|--description|--error)
            (($# >= 2)) || exit 2
            case $1 in --prompt) prompt=$2 ;; --description) description=$2 ;; --error) error=$2 ;; esac
            shift 2 ;;
        --assuan) format=assuan; shift ;;
        --check-owner) [[ $# == 2 ]] || exit 2; check_owner "$2"; exit $? ;;
        *) exit 2 ;;
    esac
done

runtime=${XDG_RUNTIME_DIR:-}
[[ $runtime == /* ]] && private_directory "$runtime" || exit 2
runtime_root=$runtime/quickshell-picker
mkdir -p -- "$runtime_root" 2>/dev/null || exit 2
private_directory "$runtime_root" || exit 2
picker_timeout=${QS_PICKER_TIMEOUT:-300}
[[ $picker_timeout =~ ^[1-9][0-9]{0,2}$ ]] && ((picker_timeout <= 600)) || exit 2
helper_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_root=$(cd -- "$helper_dir/../../.." && pwd)
ipc() { timeout 3 "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "${QS_PICKER_CONFIG:-$config_root}" call launcher "$@" >/dev/null 2>&1; }
request_dir=$(mktemp -d "$runtime_root/request.XXXXXXXX") || exit 2
cleanup() {
    unset response chunk
    if [[ -n ${reply_fd:-} ]]; then exec {reply_fd}>&-; fi
    ipc cancel "$request_dir" || true
    rm -rf -- "$request_dir"
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP
mkfifo -m 600 "$request_dir/reply" || exit 2
owner_start=$(process_start "$$") || exit 2
jq -nc --arg prompt "$prompt" --arg description "$description" --arg error "$error" \
    --argjson pid "$$" --arg start "$owner_start" \
    '{kind:"secret",items:[],prompt:$prompt[:500],description:$description[:2000],
      errorText:$error[:1000],ownerPid:$pid,ownerStart:$start}' > "$request_dir/request.json" || exit 2
exec {reply_fd}<>"$request_dir/reply"
ipc open "$request_dir" || exit 2
deadline=$((SECONDS + picker_timeout))
response=''
while ((SECONDS < deadline)); do
    chunk=''
    read_status=0
    IFS= read -r -n "$((65536 - ${#response}))" -t 1 chunk <&"$reply_fd" || read_status=$?
    response+=$chunk
    ((${#response} < 65536)) || exit 2
    if ((read_status == 0)); then
        # Validate one JSON object before extracting any value. Never put secrets
        # in jq arguments; both validation and output consume the private pipe.
        printf '%s' "$response" | jq -es 'length == 1 and (.[0] |
            type == "object" and (.status == "cancelled" or
            (.status == "accepted" and keys == ["secret","status"] and (.secret | type == "string"))))' >/dev/null 2>&1 || exit 2
        if printf '%s' "$response" | jq -e ' .status == "cancelled"' >/dev/null 2>&1; then exit 1; fi
        if [[ $format == assuan ]]; then
            printf '%s' "$response" | jq -j '"D " + (.secret | gsub("%";"%25") |
                gsub("\r";"%0D") | gsub("\n";"%0A") | gsub("\u0000";"%00")) + "\nOK\n"' 2>/dev/null || exit 2
        else
            printf '%s' "$response" | jq -j '.secret' 2>/dev/null || exit 2
        fi
        exit 0
    fi
    ipc alive || exit 2
done
exit 2
