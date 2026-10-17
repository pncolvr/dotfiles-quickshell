#!/usr/bin/env bash
# Noninteractive QR/clipboard worker: one JSON {text} line in, PNG data URI out.
# Payloads stay in pipes/memory; no input, request or image files are created.
set -euo pipefail
active_pid=''
cleanup() {
    [[ -z $active_pid ]] || kill -TERM -- "-$active_pid" 2>/dev/null || true
    [[ -z $active_pid ]] || wait "$active_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
fail() { jq -nc --arg message "$1" --argjson args "${2:-[]}" '{status:"error",message:$message,args:$args}'; exit 2; }
# Each tool pipeline gets its own process group so cancellation stops all children.
run() {
    local output_fd input_fd result=0
    coproc TOOL { exec setsid "$@"; }
    active_pid=$TOOL_PID
    exec {output_fd}<&"${TOOL[0]}"
    input_fd=${TOOL[1]}
    printf '%s' "$payload" >&"$input_fd"
    exec {input_fd}>&-
    output=''
    IFS= read -r output <&"$output_fd" || true
    exec {output_fd}<&-
    wait "$active_pid" || result=$?
    active_pid=''
    return "$result"
}
IFS= read -r payload || exit 0
printf '%s' "$payload" | jq -e 'type == "object" and (.text | type == "string" and length > 0)' >/dev/null \
    || fail 'qr.errors.encode'
for dependency in qrencode wl-copy base64 setsid; do
    command -v "$dependency" >/dev/null || fail qr.errors.dependency "$(jq -nc --arg dependency "$dependency" '[$dependency]')"
done
# Original PNG defaults: level L, 3-pixel modules, 4-module margin. Text never enters argv.
run bash -c 'set -o pipefail; jq -j .text | qrencode --type=PNG -o - | base64 -w0' \
    || fail 'qr.errors.encode'
image=$output
payload=$image
# Encode fully before touching the clipboard. wl-copy keeps its own image copy.
run bash -c 'set -o pipefail; base64 --decode | wl-copy --type image/png' \
    || fail 'qr.errors.copy'
payload=''
printf '%s' "$image" | jq -Rsc '{status:"ready",image:("data:image/png;base64," + .)}'
