#!/usr/bin/env bash
# Binary payloads stay in private files. stdout is a newline-delimited JSON protocol.
set -euo pipefail
umask 077
clipboard_dir=${QS_CLIPBOARD_DIRECTORY:?Clipboard directory is required}
max_bytes=${QS_CLIPBOARD_MAX_BYTES:-10000000}
[[ $max_bytes =~ ^[1-9][0-9]*$ ]] || exit 2
initialize() {
    mkdir -p -- "$clipboard_dir"
    [[ -O $clipboard_dir && ! -L $clipboard_dir ]] || exit 2
    chmod 700 -- "$clipboard_dir"
}
validate_id() { [[ $1 =~ ^[a-f0-9]{64}$ ]] || exit 2; }

plain_text() {
    case ${1,,} in
        text/plain|text/plain\;charset=utf-8|text/plain\;charset=us-ascii) return 0 ;;
        *) return 1 ;;
    esac
}
text_size() {
    # Find the final non-NUL byte without decoding text or losing interior NULs.
    LC_ALL=C gawk 'BEGIN { RS = "\0" }
        length($0) { end = offset + length($0) }
        { offset += length($0) + length(RT) }
        END { printf "%.0f\n", end }' "$1"
}

capture() {
    [[ ${CLIPBOARD_STATE:-data} == data ]] || { cat >/dev/null; exit 0; }
    mime=${CLIPBOARD_TYPE:-${2:-text/plain}}
    case $mime in
        text/*) kind=text; limit=$((max_bytes < 1000000 ? max_bytes : 1000000)) ;;
        image|image/png|image/jpeg|image/webp|image/bmp|image/tiff|image/gif) kind=image; limit=$max_bytes ;;
        *) cat >/dev/null; exit 0 ;;
    esac
    initialize
    temporary=$(mktemp "$clipboard_dir/.capture.XXXXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    # Read a bounded payload, then drain stdin so the source can finish normally.
    timeout 5s head -c "$((limit + 1))" > "$temporary"
    timeout 5s cat >/dev/null
    size=$(stat -c %s -- "$temporary")
    [[ $size -gt 0 && $size -le $limit ]] || exit 0
    if plain_text "$mime"; then
        size=$(text_size "$temporary")
        [[ $size -gt 0 ]] || exit 0
        truncate -s "$size" -- "$temporary"
    fi
    if [[ $kind == image ]]; then
        detected=$(file --brief --mime-type -- "$temporary")
        if [[ $mime == image ]]; then mime=$detected; fi
        case $mime in image/png|image/jpeg|image/webp|image/bmp|image/tiff|image/gif) ;; *) exit 0 ;; esac
        [[ $detected == "$mime" ]] || exit 0
    fi
    id=$({ printf '%s\0' "$mime"; cat -- "$temporary"; } | sha256sum)
    id=${id%% *}
    # Hold the shared lock only when publishing a complete payload and JSON line.
    # A stalled source must not block either watcher while reading its bytes.
    exec {lock_fd}>"$clipboard_dir/.lock"
    flock -x -w 5 "$lock_fd"
    # Renaming within the same filesystem prevents partial payload reads.
    mv -f -- "$temporary" "$clipboard_dir/$id"
    if [[ $kind == text ]]; then
        jq -cn --arg id "$id" --arg mime "$mime" --arg kind "$kind" --argjson bytes "$size" \
            --rawfile text "$clipboard_dir/$id" '{id:$id,mime:$mime,kind:$kind,bytes:$bytes,text:$text}'
    else
        jq -cn --arg id "$id" --arg mime "$mime" --arg kind "$kind" --argjson bytes "$size" \
            '{id:$id,mime:$mime,kind:$kind,bytes:$bytes,text:""}'
    fi
}

case ${1:-} in
    watch)
        source "$(dirname -- "${BASH_SOURCE[0]}")/../processes/process-identity.sh"
        watch_pid=$BASHPID
        owner_pid=$PPID
        watch_start=$(process_identity "$watch_pid") || exit 2
        owner_start=$(process_identity "$owner_pid") || exit 2
        initialize
        # The installed wl-clipboard does not expose CLIPBOARD_TYPE. Watch each
        # supported family directly; a lock serializes stdout and file writes.
        watcher_pids=()
        guard_pid=''
        cleanup_watchers() {
            [[ -z $guard_pid ]] || kill "$guard_pid" 2>/dev/null || true
            for watcher_pid in "${watcher_pids[@]}"; do kill -- "-$watcher_pid" 2>/dev/null || true; done
            wait "${watcher_pids[@]}" 2>/dev/null || true
            [[ -z $guard_pid ]] || wait "$guard_pid" 2>/dev/null || true
        }
        trap cleanup_watchers EXIT
        trap 'exit 0' TERM INT HUP
        # Each watcher owns a process group so cleanup also stops active captures.
        setsid wl-paste --type text --watch bash "${BASH_SOURCE[0]}" capture text/plain &
        watcher_pids+=("$!")
        setsid wl-paste --type image --watch bash "${BASH_SOURCE[0]}" capture image &
        watcher_pids+=("$!")
        # Quickshell can kill the supervisor before its EXIT trap runs on reload.
        # Match owner and supervisor identities so PID reuse cannot keep orphans alive.
        (
            trap - EXIT TERM INT HUP
            while process_alive "$watch_pid" "$watch_start" "$PROCESS_BOOT_ID" \
                && process_alive "$owner_pid" "$owner_start" "$PROCESS_BOOT_ID"; do sleep 1; done
            for watcher_pid in "${watcher_pids[@]}"; do kill -- "-$watcher_pid" 2>/dev/null || true; done
        ) >/dev/null 2>&1 &
        guard_pid=$!
        wait -n "${watcher_pids[@]}"
        exit 1
        ;;
    capture) capture "$@" ;;
    delete)
        shift
        for id in "$@"; do validate_id "$id"; rm -f -- "$clipboard_dir/$id"; done
        ;;
    copy-image)
        image_path=${2:?}
        [[ -f $image_path && -r $image_path ]]
        mime=$(file --brief --mime-type -- "$image_path")
        case $mime in image/*) ;; *) exit 2 ;; esac
        exec wl-copy --type "$mime" < "$image_path"
        ;;
    restore)
        id=${2:?}; mime=${3:?}; validate_id "$id"
        [[ -f $clipboard_dir/$id && ! -L $clipboard_dir/$id ]]
        if plain_text "$mime"; then
            # Older entries may still include a remote text terminator. Keep the
            # stored bytes and their content hash intact while restoring cleanly.
            size=$(text_size "$clipboard_dir/$id")
            head -c "$size" -- "$clipboard_dir/$id" | wl-copy --type "$mime"
        else
            exec wl-copy --type "$mime" < "$clipboard_dir/$id"
        fi
        ;;
    paste)
        id=${2:?}; mime=${3:?}; destination=${4:?}; class_name=${5:-}
        [[ $destination =~ ^0x[0-9a-fA-F]+$ ]] || { printf 'The original window is unavailable.\n' >&2; exit 1; }
        bash "${BASH_SOURCE[0]}" restore "$id" "$mime"
        sleep 0.15
        hyprctl clients -j | jq -e --arg address "$destination" 'any(.[]; .address == $address and .mapped != false)' >/dev/null \
            || { printf 'The original window has closed.\n' >&2; exit 1; }
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$destination\" })" >/dev/null
        focused=false
        for ((attempt=0; attempt<20; attempt++)); do
            if hyprctl activewindow -j | jq -e --arg address "$destination" '.address == $address' >/dev/null; then focused=true; break; fi
            sleep 0.025
        done
        [[ $focused == true ]] || { printf 'Could not focus the original window.\n' >&2; exit 1; }
        sleep 0.1
        hyprctl activewindow -j | jq -e --arg address "$destination" '.address == $address' >/dev/null \
            || { printf 'Focus changed before paste.\n' >&2; exit 1; }
        case ${class_name,,} in
            *ghostty*|*kitty*|*alacritty*|*foot*|*wezterm*|*konsole*|*terminal*) ydotool key 29:1 42:1 47:1 47:0 42:0 29:0 ;;
            *) ydotool key 29:1 47:1 47:0 29:0 ;;
        esac
        ;;
    prune)
        initialize
        # The repository sends the authoritative IDs over stdin, never SQL from Bash.
        keep=$(jq -ce 'if type == "array" and all(.[]; type == "string" and test("^[a-f0-9]{64}$")) then . else error("Invalid IDs") end')
        shopt -s nullglob
        for payload in "$clipboard_dir"/*; do
            id=${payload##*/}; validate_id "$id"
            if ! jq -e --arg id "$id" 'index($id) != null' <<< "$keep" >/dev/null; then rm -f -- "$payload"; fi
        done
        ;;
    *) printf 'Usage: clipboard.sh watch|capture|copy-image PATH|restore ID MIME|paste ID MIME ADDRESS CLASS|delete ID...|prune\n' >&2; exit 2 ;;
esac
