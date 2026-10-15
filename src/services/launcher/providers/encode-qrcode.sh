#!/usr/bin/env bash
set -euo pipefail

provider_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$provider_dir/_common/utils.sh"

qr_alert() {
    "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "${QS_PICKER_CONFIG:-$provider_dir/../../../..}" \
        call alerts post encode-qrcode "$1" "$2" 3000 >/dev/null 2>&1 || true
}

fail() {
    printf '%s\n' "$1" >&2
    qr_alert "$1" error
    exit 2
}

for dependency in qrencode wl-copy; do
    command -v "$dependency" >/dev/null || fail "QR encoding requires $dependency"
done

umask 077
work_dir=$(mktemp -d "$(get_temp_dir)/encode-qrcode.XXXXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
cat > "$work_dir/prompt.json" <<'JSON'
{
    "prompt": "Text to encode",
    "acceptLabel": "Generate QR code",
    "allowTyped": true,
    "items": []
}
JSON

status=0
response=$(bash "$PICKER_LAUNCHER" --json-response "$work_dir/prompt.json") || status=$?
case $status in
    0) ;;
    1) exit 0 ;;
    *) fail "Could not open QR code input" ;;
esac
jq -e '.items[0].result | type == "string" and length > 0' <<< "$response" >/dev/null || exit 0

# JSON and stdin preserve literal text, including delimiters and trailing newlines.
# Keep qrencode's original defaults: PNG, level L, 3-pixel modules, 4-module margin.
if ! jq -j '.items[0].result' <<< "$response" | qrencode --type=PNG -o "$work_dir/qrcode.png"; then
    fail "Could not encode QR code"
fi
# Finish encoding before touching the clipboard, so encoder errors preserve it.
if ! wl-copy --type image/png < "$work_dir/qrcode.png"; then
    fail "Could not copy QR code"
fi
qr_alert "QR code copied to clipboard" success

# Keep the private PNG alive until the native viewer is dismissed. wl-copy has
# already read its own copy, so closing the preview leaves the clipboard intact.
jq -n --arg path "$work_dir/qrcode.png" '{kind:"image", allowTyped:false, acceptLabel:"Close",
    items:[{title:"QR code", result:"close",
        image:("file://" + ($path | split("/") | map(@uri) | join("/")))}]}' > "$work_dir/preview.json"
status=0
bash "$PICKER_LAUNCHER" --json-response "$work_dir/preview.json" >/dev/null || status=$?
case $status in 0|1) ;; *) fail "Could not display QR code" ;; esac
