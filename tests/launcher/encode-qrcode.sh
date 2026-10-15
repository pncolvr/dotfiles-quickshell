#!/usr/bin/env bash
# Real QR encoding with isolated picker, alerts and clipboard; no desktop actions.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-encode-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/bin" "$test_dir/src/services/launcher/providers/_common"
export QR_TEST_ENCODER=$(command -v qrencode)
export QR_TEST_DIR="$test_dir" XDG_RUNTIME_DIR="$test_dir/runtime"
export QS_PICKER_EXECUTABLE="$test_dir/bin/qs" QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=4
export PATH="$test_dir/bin:$PATH"
cp "$project_root/src/services/launcher/launcher.sh" "$test_dir/src/services/launcher/"
cp "$project_root/src/services/launcher/providers/encode-qrcode.sh" "$test_dir/src/services/launcher/providers/"
cp "$project_root/src/services/launcher/providers/_common/utils.sh" "$test_dir/src/services/launcher/providers/_common/"
picker="$test_dir/src/services/launcher/launcher.sh"

cat > "$test_dir/bin/qs" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${5:-} == alerts ]]; then
    jq -nc --arg message "$8" --arg kind "$9" '{message:$message,kind:$kind}' >> "$QR_TEST_DIR/alerts"
elif [[ ${6:-} == open ]]; then
    [[ ${QR_TEST_IPC_FAIL:-0} == 0 ]] || exit 9
    if jq -e '.kind == "image"' "$7/request.json" >/dev/null; then
        cp "$7/request.json" "$QR_TEST_DIR/preview.json"
        path=$(jq -r '.items[0].image | ltrimstr("file://")' "$7/request.json")
        [[ -s $path ]]
        cmp "$path" "$QR_TEST_DIR/clipboard"
        cp "$path" "$QR_TEST_DIR/preview.png"
        [[ ${QR_TEST_PREVIEW_FAIL:-0} == 0 ]] || exit 9
        printf '%s\n' '{"status":"cancelled"}' > "$7/reply"
        exit
    fi
    cp "$7/request.json" "$QR_TEST_DIR/menu.json"
    if [[ ${QR_TEST_CANCEL:-0} == 1 ]]; then
        printf '%s\n' '{"status":"cancelled"}' > "$7/reply"
    else
        jq -Rsc '{status:"accepted",items:[{title:.,result:.}],exitCode:0}' \
            "$QR_TEST_DIR/text" > "$7/reply"
    fi
fi
BASH
cat > "$test_dir/bin/qrencode" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$QR_TEST_DIR/encoder-args"
exec "$QR_TEST_ENCODER" "$@"
BASH
cat > "$test_dir/bin/wl-copy" <<'BASH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$QR_TEST_DIR/copy-args"
[[ ${QR_TEST_COPY_FAIL:-0} == 0 ]] || exit 1
cat > "$QR_TEST_DIR/clipboard"
BASH
chmod +x "$test_dir/bin/qs" "$test_dir/bin/qrencode" "$test_dir/bin/wl-copy"

reset_actions() {
    rm -f "$test_dir/encoder-args" "$test_dir/copy-args" "$test_dir/alerts" "$test_dir/menu.json" "$test_dir/preview.json" "$test_dir/preview.png"
}
check_cleanup() {
    [[ -z $(find "$test_dir/runtime" -mindepth 1 -type f -print -quit) ]]
    [[ -z $(find "$test_dir/runtime" -name 'encode-qrcode.*' -print -quit) ]]
}
expect_error() {
    jq -se 'length == 1 and .[0].kind == "error"' "$test_dir/alerts" >/dev/null
    check_cleanup
}

for text in 'https://example.test/qr?a=1&b=2' '-option | Olá 日本語 "quoted" $dollar $(touch injected) `literal` \\' $'line one\nline two\n\n'; do
    reset_actions
    printf '%s' "$text" > "$test_dir/text"
    bash "$picker" provider encode-qrcode
    jq -e '.allowTyped and .acceptLabel == "Generate QR code" and .items == []' "$test_dir/menu.json" >/dev/null
    [[ $(cat "$test_dir/copy-args") == $'--type\nimage/png' ]]
    "$QR_TEST_ENCODER" -o "$test_dir/expected.png" -- "$text"
    cmp "$test_dir/expected.png" "$test_dir/clipboard"
    cmp "$test_dir/expected.png" "$test_dir/preview.png"
    jq -e '.kind == "image" and .allowTyped == false' "$test_dir/preview.json" >/dev/null
    if command -v zbarimg >/dev/null; then
        printf '%s\n' "$text" > "$test_dir/expected-text"
        zbarimg --raw -q "$test_dir/clipboard" > "$test_dir/decoded" 2>/dev/null
        cmp "$test_dir/expected-text" "$test_dir/decoded"
    fi
    jq -se 'length == 1 and .[0].kind == "success" and .[0].message == "QR code copied to clipboard"' "$test_dir/alerts" >/dev/null
    check_cleanup
done
printf 'PASS: QR PNGs retain original encoding, preserve literal text and match the displayed image while clipboard content survives closing\n'

cp "$test_dir/clipboard" "$test_dir/saved-clipboard"
for mode in cancel empty; do
    reset_actions
    : > "$test_dir/text"
    if [[ $mode == cancel ]]; then
        QR_TEST_CANCEL=1 bash "$picker" provider encode-qrcode
    else
        bash "$picker" provider encode-qrcode
    fi
    [[ ! -f $test_dir/encoder-args && ! -f $test_dir/copy-args && ! -f $test_dir/alerts && ! -f $test_dir/preview.json ]]
    cmp "$test_dir/saved-clipboard" "$test_dir/clipboard"
    check_cleanup
done
printf 'PASS: cancellation and empty input leave the clipboard untouched without alerts\n'

reset_actions
if QR_TEST_IPC_FAIL=1 bash "$picker" provider encode-qrcode 2> "$test_dir/error"; then exit 1; fi
[[ ! -f $test_dir/encoder-args && ! -f $test_dir/copy-args ]]
expect_error
printf 'PASS: failed picker IPC reports an error and skips encoding\n'

# A genuine over-capacity encode must never start wl-copy with an empty PNG.
reset_actions
printf '%10000s' 'too long' > "$test_dir/text"
if bash "$picker" provider encode-qrcode 2> "$test_dir/error"; then exit 1; fi
[[ -f $test_dir/encoder-args && ! -f $test_dir/copy-args ]]
cmp "$test_dir/saved-clipboard" "$test_dir/clipboard"
expect_error
printf 'PASS: encoder failure reports an error and preserves the previous clipboard\n'

reset_actions
printf '%s' 'copy failure' > "$test_dir/text"
if QR_TEST_COPY_FAIL=1 bash "$picker" provider encode-qrcode 2> "$test_dir/error"; then exit 1; fi
cmp "$test_dir/saved-clipboard" "$test_dir/clipboard"
expect_error
printf 'PASS: clipboard failure reports an error without claiming success\n'

reset_actions
printf '%s' 'preview unavailable' > "$test_dir/text"
if QR_TEST_PREVIEW_FAIL=1 bash "$picker" provider encode-qrcode 2> "$test_dir/error"; then exit 1; fi
jq -se 'length == 2 and .[0].kind == "success" and .[1].kind == "error"
    and .[1].message == "Could not display QR code"' "$test_dir/alerts" >/dev/null
cmp "$test_dir/preview.png" "$test_dir/clipboard"
check_cleanup
printf 'PASS: preview failure reports an error and keeps the generated clipboard image\n'
