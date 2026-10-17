#!/usr/bin/env bash
# Prepared capture executor. Native Quickshell owns choices and overlay readiness.
# The completed-image Satty stage detaches so annotation survives bar/config reloads.
set -euo pipefail
worker_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$worker_dir/_common/utils.sh"
umask 077
active_pid=''; freezer_pid=''; editor_pid=''; workspace=''; transferred=false
stop_group() {
    local pid=$1
    [[ -n $pid ]] || return 0
    kill -TERM -- "-$pid" 2>/dev/null || true
    kill -KILL -- "-$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}
cleanup() {
    stop_group "$active_pid"
    stop_group "$freezer_pid"
    if [[ $transferred == false ]]; then
        stop_group "$editor_pid"
        [[ -z $workspace ]] || rm -rf -- "$workspace"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
reply() { jq -nc --arg status "$1" --arg message "${2:-}" --argjson args "${3:-[]}" '{status:$status,message:$message,args:$args}'; }
fail() { reply error "$1" "${2:-[]}"; exit 2; }
# Child operations get their own process group, never pgrep/pkill of other sessions.
run() {
    local output=$1 result=0; shift
    setsid "$@" <&0 > "$output" 2> "$workspace/error" & active_pid=$!
    wait "$active_pid" || result=$?
    active_pid=''
    return "$result"
}
alert() {
    "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "$config_root" call alerts postMessage screenshot "$1" "${3:-[]}" "$2" 4000 false >/dev/null 2>&1 || true
}
if [[ ${1:-} == --annotate ]]; then
    candidate=${2:?}; destination=${3:?}; config_root=${4:?}
    # Reject an invalid internal handoff before adopting any directory for cleanup.
    capture_root=${XDG_RUNTIME_DIR:-/tmp}
    [[ $candidate == "$capture_root"/quickshell-capture.* ]] || exit 2
    [[ ${candidate%/*} == "$capture_root" && -d $candidate && -O $candidate && ! -L $candidate ]] || exit 2
    [[ $(stat -c %a -- "$candidate") == 700 && -s $candidate/capture.png && ! -L $candidate/capture.png ]] || exit 2
    workspace=$candidate
    mkdir -p -- "$destination" || { alert 'screenshot.errors.createFolder' error; exit 2; }
    # Reserve a unique name without overwriting an earlier capture in the same second.
    base="$destination/$(date '+Screenshot %Y-%m-%d at %Hh%Mm%Ss')"
    filename="$base.png"; suffix=0
    while ! (set -o noclobber; : > "$filename") 2>/dev/null; do
        suffix=$((suffix + 1)); filename="$base ($suffix).png"
        [[ $suffix -le 1000 ]] || { alert 'screenshot.errors.reserveFilename' error; exit 2; }
    done
    saved=false
    annotation_cleanup() {
        if [[ $saved == false && -f $filename && ! -s $filename ]]; then rm -f -- "$filename"; fi
        cleanup
    }
    trap annotation_cleanup EXIT
    result=0
    run "$workspace/editor-output" satty --filename "$workspace/capture.png" --output-filename "$filename" || result=$?
    if [[ -s $filename ]]; then
        saved=true
        alert screenshot.status.saved success "$(jq -nc --arg filename "${filename##*/}" '[$filename]')"
        open_file_explorer "$filename" || alert 'screenshot.errors.openFolder' warning
    elif ((result != 0)); then
        alert 'screenshot.errors.editor' error
        exit 2
    fi
    exit 0
fi
# Direct prepared tool use works offline through the existing Config exporter.
case ${1:-} in
    --prepared) method=${2:?}; destination=${3:?}; config_root=${4:?} ;;
    region|output|window|ocr|qrcode)
        method=$1
        load_provider_config || exit 2
        destination=$SCREENSHOT_FOLDER
        config_root=${QS_PICKER_CONFIG:-$(cd -- "$worker_dir/../../../.." && pwd)}
        ;;
    *) printf 'Usage: screenshot.sh {region|output|window|ocr|qrcode}\n' >&2; exit 2 ;;
esac
case $method in region|output|window|ocr|qrcode) ;; *) fail 'screenshot.errors.method' ;; esac
for dependency in jq setsid timeout hyprpicker slurp grim; do
    command -v "$dependency" >/dev/null || fail screenshot.errors.dependency "$(jq -nc --arg dependency "$dependency" '[$dependency]')"
done
case $method in
    ocr) command -v tesseract >/dev/null || fail 'screenshot.errors.ocrEngine'; command -v wl-copy >/dev/null || fail 'screenshot.errors.ocrClipboard' ;;
    qrcode) command -v zbarimg >/dev/null || fail 'screenshot.errors.qrDecoder'; command -v wl-copy >/dev/null || fail 'screenshot.errors.qrClipboard' ;;
    *) command -v satty >/dev/null || fail 'screenshot.errors.editorMissing' ;;
esac
workspace=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/quickshell-capture.XXXXXXXX") || fail 'screenshot.errors.prepare'
deadline=$((SECONDS + 30))
capture_run() {
    local output=$1 remaining=$((deadline - SECONDS)); shift
    ((remaining > 0)) || return 124
    run "$output" timeout --foreground --kill-after=1 "$remaining" "$@"
}
# Freeze initialization belongs to hyprpicker; picker/submap closing has no fixed delay.
setsid hyprpicker -r -z > /dev/null 2> "$workspace/freezer-error" & freezer_pid=$!
sleep 0.2
kill -0 "$freezer_pid" 2>/dev/null || fail 'screenshot.errors.freeze'
selector=region
case $method in output|window) selector=$method ;; esac
result=0
# slurp reads optional rectangles from stdin before mapping. A QProcess pipe may
# remain open, so modes without predefined boxes must receive an explicit EOF.
case $selector in
    region) capture_run "$workspace/geometry" slurp -d < /dev/null || result=$? ;;
    output) capture_run "$workspace/geometry" slurp -or < /dev/null || result=$? ;;
    window)
        capture_run "$workspace/monitors" hyprctl -j monitors || fail 'screenshot.errors.monitors'
        capture_run "$workspace/clients" hyprctl -j clients || fail 'screenshot.errors.windows'
        jq -r --slurpfile monitors "$workspace/monitors" '
            [$monitors[0][] | .activeWorkspace.id, .specialWorkspace.id] as $visible
            | .[] | select(.mapped != false and .hidden != true)
            | select(.workspace.id as $id | $visible | index($id))
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
        ' "$workspace/clients" > "$workspace/boxes" || fail 'screenshot.errors.windows'
        [[ -s $workspace/boxes ]] || { reply cancelled; exit 0; }
        capture_run "$workspace/geometry" slurp -r < "$workspace/boxes" || result=$?
        ;;
esac
case $result in
    0) ;;
    1)
        # slurp also uses exit 1 for setup/backend failures; only cancellation is quiet.
        if [[ -s $workspace/error ]] && ! grep -Eq '^(slurp: )?selection cancelled$' "$workspace/error"; then
            fail 'screenshot.errors.selection'
        fi
        reply cancelled; exit 0
        ;;
    124|137) fail 'screenshot.errors.timeout' ;;
    *) fail 'screenshot.errors.selection' ;;
esac
geometry=$(cat "$workspace/geometry")
[[ $geometry =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]] || fail 'screenshot.errors.invalidSelection'
if [[ $selector == window ]]; then
    # Clip partially off-screen windows to logical monitor bounds, including scale/rotation.
    geometry=$(jq -nr --arg geometry "$geometry" --slurpfile monitors "$workspace/monitors" '
        ($geometry | capture("(?<x>-?[0-9]+),(?<y>-?[0-9]+) (?<w>[0-9]+)x(?<h>[0-9]+)") | map_values(tonumber)) as $r
        | [$monitors[0][] | {x,y,w: ((if .transform % 2 == 1 then .height else .width end) / .scale | round),
            h: ((if .transform % 2 == 1 then .width else .height end) / .scale | round)}] as $m
        | ([$r.x, ($m | map(.x) | min)] | max) as $x
        | ([$r.y, ($m | map(.y) | min)] | max) as $y
        | (([$r.x+$r.w, ($m | map(.x+.w) | max)] | min)-$x) as $w
        | (([$r.y+$r.h, ($m | map(.y+.h) | max)] | min)-$y) as $h
        | if $w>0 and $h>0 then "\($x),\($y) \($w)x\($h)" else empty end
    ') || fail 'screenshot.errors.boundWindow'
    [[ -n $geometry ]] || fail 'screenshot.errors.outsideMonitors'
fi
capture_run "$workspace/capture.png" grim -g "$geometry" - || fail 'screenshot.errors.area'
[[ -s $workspace/capture.png ]] || fail 'screenshot.errors.noImage'
stop_group "$freezer_pid"; freezer_pid=''
case $method in
    region|output|window)
        setsid bash "$worker_dir/screenshot.sh" --annotate "$workspace" "$destination" "$config_root" < /dev/null > /dev/null 2>&1 & editor_pid=$!
        transferred=true
        reply editing
        ;;
    ocr|qrcode)
        result=0
        case $method in
            ocr) run "$workspace/text" tesseract stdin stdout -l por < "$workspace/capture.png" || result=$? ;;
            qrcode) run "$workspace/text" zbarimg --raw -q - < "$workspace/capture.png" || result=$? ;;
        esac
        case $method:$result in
            ocr:0|qrcode:0) ;;
            qrcode:4) reply empty 'screenshot.empty.qr'; exit 0 ;;
            *) fail 'screenshot.errors.decode' ;;
        esac
        if [[ ! -s $workspace/text ]] || ! LC_ALL=C grep -q '[^[:space:]]' "$workspace/text"; then
            case $method in
                ocr) reply empty 'screenshot.empty.text' ;;
                qrcode) reply empty 'screenshot.empty.qr' ;;
            esac
            exit 0
        fi
        run /dev/null wl-copy < "$workspace/text" || fail 'screenshot.errors.copy'
        jq -Rsc '{status:"ready",text:.}' "$workspace/text"
        ;;
esac
