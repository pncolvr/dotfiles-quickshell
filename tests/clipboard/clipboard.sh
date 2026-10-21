#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-clipboard-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export QS_CLIPBOARD_DIRECTORY="$test_dir/payloads" QS_CLIPBOARD_MAX_BYTES=1000000
export CLIPBOARD_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"
helper="$project_root/src/services/clipboard/clipboard.sh"
cat > "$test_dir/bin/wl-copy" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CLIPBOARD_TEST_DIR/mime"
cat > "$CLIPBOARD_TEST_DIR/restored"
SH
cat > "$test_dir/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
if [[ $1 == clients ]]; then
    if [[ -f $CLIPBOARD_TEST_DIR/closed ]]; then printf '[]'; else printf '[{"address":"0xab","mapped":true}]'; fi
elif [[ $1 == activewindow ]]; then printf '{"address":"0xab"}'
fi
SH
cat > "$test_dir/bin/ydotool" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CLIPBOARD_TEST_DIR/keys"
SH
chmod +x "$test_dir/bin/"*
printf 'Olá\nline two\n\n' > "$test_dir/text"
entry=$(CLIPBOARD_TYPE=text/plain CLIPBOARD_STATE=data bash "$helper" capture < "$test_dir/text")
id=$(jq -r '.id' <<< "$entry")
[[ $(jq -r '.text' <<< "$entry") == $(<"$test_dir/text") ]]
cmp "$test_dir/text" "$QS_CLIPBOARD_DIRECTORY/$id"
bash "$helper" restore "$id" text/plain
cmp "$test_dir/text" "$test_dir/restored"
[[ $(<"$test_dir/mime") == '--type text/plain' ]]
[[ -z $(CLIPBOARD_STATE=sensitive bash "$helper" capture < "$test_dir/text") ]]
[[ -z $(CLIPBOARD_STATE=nil bash "$helper" capture < /dev/null) ]]
[[ -z $(QS_CLIPBOARD_MAX_BYTES=3 bash "$helper" capture < "$test_dir/text") ]]
[[ $(stat -c %a "$QS_CLIPBOARD_DIRECTORY/$id") == 600 ]]

# Remote plain text may include C-string terminators; only the suffix is removed.
printf '  Olá\0inside\r\nline two\n\t' > "$test_dir/clean-text"
{ cat "$test_dir/clean-text"; printf '\0\0'; } > "$test_dir/terminated-text"
for mime in text/plain 'text/plain;charset=utf-8'; do
    nul_entry=$(CLIPBOARD_TYPE="$mime" bash "$helper" capture < "$test_dir/terminated-text")
    nul_id=$(jq -r .id <<< "$nul_entry")
    cmp "$test_dir/clean-text" "$QS_CLIPBOARD_DIRECTORY/$nul_id"
    jq -j .text <<< "$nul_entry" > "$test_dir/json-text"
    cmp "$test_dir/clean-text" "$test_dir/json-text"
    [[ $(jq -r .bytes <<< "$nul_entry") == $(stat -c %s "$test_dir/clean-text") ]]
    clean_entry=$(CLIPBOARD_TYPE="$mime" bash "$helper" capture < "$test_dir/clean-text")
    [[ $(jq -r .id <<< "$clean_entry") == "$nul_id" ]]
    bash "$helper" restore "$nul_id" "$mime"
    cmp "$test_dir/clean-text" "$test_dir/restored"
done
printf 'line\0\n' > "$test_dir/interior-nul"
interior_entry=$(CLIPBOARD_TYPE=text/plain bash "$helper" capture < "$test_dir/interior-nul")
cmp "$test_dir/interior-nul" "$QS_CLIPBOARD_DIRECTORY/$(jq -r .id <<< "$interior_entry")"
[[ -z $(printf '\0\0' | CLIPBOARD_TYPE=text/plain bash "$helper" capture) ]]
[[ -z $(printf 'ab\0\0' | CLIPBOARD_TYPE=text/plain QS_CLIPBOARD_MAX_BYTES=3 bash "$helper" capture) ]]

# Clean old entries on restoration without changing the bytes behind their IDs.
legacy_id=$({ printf '%s\0' text/plain; cat "$test_dir/terminated-text"; } | sha256sum)
legacy_id=${legacy_id%% *}
cp "$test_dir/terminated-text" "$QS_CLIPBOARD_DIRECTORY/$legacy_id"
bash "$helper" restore "$legacy_id" text/plain
cmp "$test_dir/clean-text" "$test_dir/restored"
cmp "$test_dir/terminated-text" "$QS_CLIPBOARD_DIRECTORY/$legacy_id"

# NUL bytes belong to the encoding in UTF-16, so that payload stays unchanged.
printf 'A\0B\0\0\0' > "$test_dir/utf16-text"
encoded_entry=$(CLIPBOARD_TYPE='text/plain;charset=utf-16le' bash "$helper" capture < "$test_dir/utf16-text")
encoded_id=$(jq -r .id <<< "$encoded_entry")
cmp "$test_dir/utf16-text" "$QS_CLIPBOARD_DIRECTORY/$encoded_id"
bash "$helper" restore "$encoded_id" 'text/plain;charset=utf-16le'
cmp "$test_dir/utf16-text" "$test_dir/restored"

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=' | base64 -d > "$test_dir/image.png"
image_entry=$(CLIPBOARD_TYPE=image/png bash "$helper" capture < "$test_dir/image.png")
image_id=$(jq -r '.id' <<< "$image_entry")
[[ $(jq -r '.kind' <<< "$image_entry") == image ]]
cp "$test_dir/image.png" "$test_dir/image with # % and spaces.png"
bash "$helper" copy-image "$test_dir/image with # % and spaces.png"
cmp "$test_dir/image.png" "$test_dir/restored"
[[ $(<"$test_dir/mime") == '--type image/png' ]]
if bash "$helper" copy-image "$test_dir/text"; then exit 1; fi
if bash "$helper" copy-image "$test_dir/missing.png"; then exit 1; fi
bash "$helper" restore "$image_id" image/png
cmp "$test_dir/image.png" "$test_dir/restored"
[[ -z $(CLIPBOARD_TYPE=image/png bash "$helper" capture < "$test_dir/text") ]]
{ cat "$test_dir/image.png"; printf '\0\0'; } > "$test_dir/padded.png"
padded_entry=$(CLIPBOARD_TYPE=image/png bash "$helper" capture < "$test_dir/padded.png")
padded_id=$(jq -r .id <<< "$padded_entry")
cmp "$test_dir/padded.png" "$QS_CLIPBOARD_DIRECTORY/$padded_id"
bash "$helper" restore "$padded_id" image/png
cmp "$test_dir/padded.png" "$test_dir/restored"
printf 'PASS: plain-text terminators are removed before indexing and on legacy restoration; whitespace, embedded NULs, UTF-16 and image bytes are preserved\n'

bash "$helper" paste "$id" text/plain 0xab ghostty
[[ $(<"$test_dir/keys") == 'key 29:1 42:1 47:1 47:0 42:0 29:0' ]]
bash "$helper" paste "$id" text/plain 0xab browser
[[ $(<"$test_dir/keys") == 'key 29:1 47:1 47:0 29:0' ]]
rm "$test_dir/keys"
touch "$test_dir/closed"
if bash "$helper" paste "$id" text/plain 0xab browser 2>/dev/null; then exit 1; fi
[[ ! -f $test_dir/keys ]]
if bash "$helper" restore '../escape' text/plain 2>/dev/null; then exit 1; fi
jq -cn --arg id "$id" '[$id]' | bash "$helper" prune
[[ -f $QS_CLIPBOARD_DIRECTORY/$id && ! -f $QS_CLIPBOARD_DIRECTORY/$image_id ]]
bash "$helper" delete "$id"
[[ ! -f $QS_CLIPBOARD_DIRECTORY/$id ]]

# A source that never closes must not hold the publication lock or block a copy.
mkfifo "$test_dir/stalled-source"
{ printf 'incomplete transfer'; sleep 8; } > "$test_dir/stalled-source" & stalled_writer=$!
bash "$helper" capture text/plain < "$test_dir/stalled-source" > "$test_dir/stalled-entry" & stalled_capture=$!
for ((attempt=0; attempt<40; attempt++)); do
    compgen -G "$QS_CLIPBOARD_DIRECTORY/.capture.*" >/dev/null && break
    sleep 0.025
done
printf 'healthy copy' | timeout 2s bash "$helper" capture text/plain > "$test_dir/healthy-entry"
jq -e '.text == "healthy copy"' "$test_dir/healthy-entry" >/dev/null
capture_status=0; wait "$stalled_capture" || capture_status=$?
[[ $capture_status == 124 && ! -s $test_dir/stalled-entry ]]
! compgen -G "$QS_CLIPBOARD_DIRECTORY/.capture.*" >/dev/null
kill "$stalled_writer" 2>/dev/null || true
wait "$stalled_writer" 2>/dev/null || true

# Mock watchers with live child processes; no access to the desktop clipboard.
cat > "$test_dir/bin/wl-paste" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == --type && $3 == --watch ]]
family=$2
printf '%s\n' "$BASHPID" > "$CLIPBOARD_TEST_DIR/watcher-$family"
sleep 30 & child=$!
printf '%s\n' "$child" > "$CLIPBOARD_TEST_DIR/child-$family"
wait "$child"
MOCK
chmod +x "$test_dir/bin/wl-paste"
watch_pid=''
cleanup_watch_test() {
    [[ -z $watch_pid ]] || kill "$watch_pid" 2>/dev/null || true
    for marker in "$test_dir"/watcher-* "$test_dir"/child-*; do
        [[ -f $marker ]] || continue
        kill "$(<"$marker")" 2>/dev/null || true
    done
    rm -rf -- "$test_dir"
}
trap cleanup_watch_test EXIT
start_watch() {
    rm -f "$test_dir"/watcher-* "$test_dir"/child-*
    bash "$helper" watch > "$test_dir/watch-output" 2> "$test_dir/watch-errors" & watch_pid=$!
    for ((attempt=0; attempt<80; attempt++)); do
        [[ -s $test_dir/child-text && -s $test_dir/child-image ]] && return
        sleep 0.025
    done
    printf 'Clipboard watchers did not start.\n' >&2; exit 1
}
assert_watchers_stopped() {
    for ((attempt=0; attempt<100; attempt++)); do
        alive=false
        for marker in "$test_dir"/watcher-* "$test_dir"/child-*; do
            state=$(ps -p "$(<"$marker")" -o stat= || true)
            [[ -z $state || $state == Z* ]] || alive=true
        done
        [[ $alive == true ]] || return 0
        sleep 0.025
    done
    printf 'Clipboard watcher or capture child survived shutdown.\n' >&2; exit 1
}
start_watch
kill -TERM "$watch_pid"
wait "$watch_pid"
watch_pid=''
assert_watchers_stopped
start_watch
kill -KILL "$watch_pid"
wait "$watch_pid" 2>/dev/null || true
watch_pid=''
assert_watchers_stopped
# Simulate a reused PID by changing only its reported kernel start time. Keep
# the real PID alive: an existence-only guard would leave both watchers running.
mkdir -p "$test_dir/identity-fixture/clipboard" "$test_dir/identity-fixture/processes"
cp "$helper" "$test_dir/identity-fixture/clipboard/clipboard.sh"
sed 's/^process_identity()/kernel_process_identity()/' \
    "$project_root/src/services/processes/process-identity.sh" > "$test_dir/identity-fixture/processes/process-identity.sh"
cat >> "$test_dir/identity-fixture/processes/process-identity.sh" <<'IDENTITY'
process_identity() {
    local start stale=''
    start=$(kernel_process_identity "$1") || return 1
    [[ ! -f $CLIPBOARD_TEST_DIR/stale-pid ]] || read -r stale < "$CLIPBOARD_TEST_DIR/stale-pid"
    if [[ $1 == "$stale" ]]; then printf '%s' "$((start + 1))"; else printf '%s' "$start"; fi
}
IDENTITY
helper="$test_dir/identity-fixture/clipboard/clipboard.sh"
for identity in owner supervisor; do
    rm -f "$test_dir/stale-pid"
    start_watch
    if [[ $identity == owner ]]; then stale_pid=$$; else stale_pid=$watch_pid; fi
    kill -0 "$stale_pid"
    printf '%s\n' "$stale_pid" > "$test_dir/stale-pid"
    assert_watchers_stopped
    wait "$watch_pid" 2>/dev/null || true
    watch_pid=''
    kill -0 "$$"
done
printf 'PASS: orphan guard rejects stale owner and supervisor identities even while their PIDs exist\n'
printf 'PASS: stalled clipboard transfers time out without blocking copies; watcher and child cleanup survives termination and forced reload\n'
printf 'PASS: clipboard byte preservation, Unicode/newlines, PNG, sensitive hints, limits, private files, target validation, paste shortcuts and cleanup\n'
