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

printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=' | base64 -d > "$test_dir/image.png"
image_entry=$(CLIPBOARD_TYPE=image/png bash "$helper" capture < "$test_dir/image.png")
image_id=$(jq -r '.id' <<< "$image_entry")
[[ $(jq -r '.kind' <<< "$image_entry") == image ]]
bash "$helper" restore "$image_id" image/png
cmp "$test_dir/image.png" "$test_dir/restored"
[[ -z $(CLIPBOARD_TYPE=image/png bash "$helper" capture < "$test_dir/text") ]]

bash "$helper" paste "$id" text/plain 0xab ghostty
[[ $(<"$test_dir/keys") == 'key 29:1 42:1 47:1 47:0 42:0 29:0' ]]
bash "$helper" paste "$id" text/plain 0xab browser
[[ $(<"$test_dir/keys") == 'key 29:1 47:1 47:0 29:0' ]]
rm "$test_dir/keys"
touch "$test_dir/closed"
if bash "$helper" paste "$id" text/plain 0xab browser 2>/dev/null; then exit 1; fi
[[ ! -f $test_dir/keys ]]
if bash "$helper" restore '../escape' text/plain 2>/dev/null; then exit 1; fi
cat > "$test_dir/bin/copyq" <<'SH'
#!/usr/bin/env bash
case $1 in
    size) printf '2\n' ;;
    eval)
        # CopyQ exposes the script at arguments[0], then CLI arguments as ByteArrays.
        [[ $2 == *'Number(str(arguments[1]))'* ]] || exit 1
        case $3 in 0) printf text/plain ;; 1) printf image/png ;; *) exit 1 ;; esac
        ;;
    read)
        case "$2:$3" in
            text/plain:0) cat "$CLIPBOARD_TEST_DIR/text" ;;
            image/png:1) cat "$CLIPBOARD_TEST_DIR/image.png" ;;
            *) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
SH
chmod +x "$test_dir/bin/copyq"
bash "$helper" import-copyq > "$test_dir/imported"
jq -se --arg text "$id" --arg image "$image_id" 'length == 2 and .[0].id == $image and .[1].id == $text' "$test_dir/imported" >/dev/null
cmp "$test_dir/text" "$QS_CLIPBOARD_DIRECTORY/$id"
cmp "$test_dir/image.png" "$QS_CLIPBOARD_DIRECTORY/$image_id"
jq -cn --arg id "$id" '[$id]' | bash "$helper" prune
[[ -f $QS_CLIPBOARD_DIRECTORY/$id && ! -f $QS_CLIPBOARD_DIRECTORY/$image_id ]]
bash "$helper" delete "$id"
[[ ! -f $QS_CLIPBOARD_DIRECTORY/$id ]]
printf 'PASS: clipboard byte preservation, Unicode/newlines, PNG, sensitive hints, limits, private files, target validation, paste shortcuts, CopyQ import and cleanup\n'
