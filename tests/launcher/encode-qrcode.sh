#!/usr/bin/env bash
# Native input/preview with real QR encoding and isolated clipboard/tool processes.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qs_bin=$(command -v qs)
fixture=$(mktemp -d /tmp/qs-qr.XXXXXX)
reload_pid=''
cleanup() {
    if [[ -n $reload_pid ]]; then kill "$reload_pid" 2>/dev/null || true; wait "$reload_pid" 2>/dev/null || true; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/r" "$fixture/home" "$fixture/bin"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
export QR_TEST_ENCODER=$(command -v qrencode) QR_TEST_DIR="$fixture"
cat > "$fixture/bin/qrencode" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$QR_TEST_DIR/encoder-args"
printf '%s\n' "$$" > "$QR_TEST_DIR/encoder-pid"
case ${QR_TEST_MODE:-} in encodeSlow|reopen) exec sleep 10 ;; esac
exec "$QR_TEST_ENCODER" "$@"
MOCK
cat > "$fixture/bin/wl-copy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$QR_TEST_DIR/copy-args"
[[ ${QR_TEST_MODE:-} != copySlow ]] || exec sleep 10
[[ ${QR_TEST_MODE:-} != copyFail ]] || exit 1
cat > "$QR_TEST_DIR/clipboard"
MOCK
cat > "$fixture/bin/qs" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected QR IPC\n' >> "$QR_TEST_DIR/ipc"
exit 1
MOCK
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '[]\n'
MOCK
chmod +x "$fixture/bin/"*
sed 's@"../../src@"src@g' "$repo_dir/tests/launcher/encode-qrcode.qml" > "$fixture/shell.qml"
export PATH="$fixture/bin:$PATH" HOME="$fixture/home"
export XDG_RUNTIME_DIR="$fixture/r" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache"
run_fixture() {
    rm -f -- "$fixture/encoder-args" "$fixture/copy-args" "$fixture/encoder-pid"
    env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        timeout -k 1 12 "$qs_bin" -p "$fixture/shell.qml" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: native QR' "$fixture/log" || rg -q 'QR FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    for ((attempt=0;attempt<80;attempt++)); do
        [[ -n $(find "$fixture/r" -maxdepth 1 -name 'encode-qrcode.*' -print -quit) ]] || break
        sleep 0.025
    done
    [[ -z $(find "$fixture/r" -maxdepth 1 -name 'encode-qrcode.*' -print -quit) && ! -e $fixture/ipc ]]
    rg 'PASS:' "$fixture/log"
}
for text in 'https://example.test/qr?a=1&b=2' '-option | Olá 日本語 "quoted" $dollar $(touch injected) `literal` \\' $'line one\nline two\n\n'; do
    QR_TEST_MODE=successEnter QR_TEST_TEXT="$text" run_fixture
    printf '%s' "$text" | "$QR_TEST_ENCODER" --type=PNG -o "$fixture/expected.png"
    cmp "$fixture/expected.png" "$fixture/clipboard"
    [[ $(cat "$fixture/copy-args") == $'--type\nimage/png' ]]
done
QR_TEST_MODE=successEscape QR_TEST_TEXT='Escape keeps clipboard' run_fixture
QR_TEST_MODE=replacePreview QR_TEST_TEXT='Replacement keeps clipboard' run_fixture
cp "$fixture/clipboard" "$fixture/saved-clipboard"
for mode in cancelInput emptyInput encodeSlow copySlow reopen; do
    QR_TEST_MODE="$mode" QR_TEST_TEXT='cancel pending' run_fixture
    cmp "$fixture/saved-clipboard" "$fixture/clipboard"
done
QR_TEST_MODE=oversize QR_TEST_TEXT=$(printf '%10000s' 'too long') run_fixture
[[ ! -e $fixture/copy-args ]]
cmp "$fixture/saved-clipboard" "$fixture/clipboard"
QR_TEST_MODE=copyFail QR_TEST_TEXT='copy failure' run_fixture
cmp "$fixture/saved-clipboard" "$fixture/clipboard"
QR_TEST_MODE=previewFail QR_TEST_TEXT='preview unavailable' run_fixture
printf '%s' 'preview unavailable' | "$QR_TEST_ENCODER" --type=PNG -o "$fixture/expected.png"
cmp "$fixture/expected.png" "$fixture/clipboard"
printf 'PASS: original QR PNG bytes, literal/trailing-newline input, clipboard ordering, cancellation and no temporary image files or picker IPC\n'

# Config reload clears an in-memory preview while the clipboard retains its own PNG.
cat > "$fixture/reload.qml" <<'QML'
import QtQml
import Quickshell
import Quickshell.Io
import "src/services"
Scope {
    FileView {
        id: state
        path: Quickshell.env("QR_TEST_DIR") + "/reload-state"
        preload: false; blockLoading: true; blockWrites: true; printErrors: false
    }
    Component.onCompleted: if (!state.text()) QrEncodeService.encode("reload cleanup")
    Connections {
        target: PickerService
        function onOpened() {
            if (PickerService.imageOnly) state.setText(String(PickerService.currentItem.image))
        }
    }
    IpcHandler {
        target: "qrtest"
        function idle(): bool { return QrEncodeService.job === null }
        function reload(): void { Qt.callLater(() => Quickshell.reload(true)) }
    }
}
QML
QT_QPA_PLATFORM=offscreen QS_NO_RELOAD_POPUP=1 QR_TEST_MODE=reload "$qs_bin" -p "$fixture/reload.qml" > "$fixture/reload-log" 2>&1 & reload_pid=$!
for ((attempt=0;attempt<100;attempt++)); do
    [[ ! -s $fixture/reload-state ]] || break
    sleep 0.025
done
[[ -s $fixture/reload-state ]] || { cat "$fixture/reload-log"; exit 1; }
node - "$fixture/reload-state" <<'NODEDATA'
const fs=require('node:fs'),image=fs.readFileSync(process.argv[2],'utf8');
if(!image.startsWith('data:image/png;base64,'))throw Error('Preview must stay in memory');
NODEDATA
"$qs_bin" ipc -p "$fixture/reload.qml" call qrtest reload
for ((attempt=0;attempt<100;attempt++)); do
    if [[ $("$qs_bin" ipc -p "$fixture/reload.qml" call qrtest idle 2>/dev/null) == true ]]; then break; fi
    sleep 0.025
done
[[ $("$qs_bin" ipc -p "$fixture/reload.qml" call qrtest idle) == true ]]
[[ -z $(find "$fixture/r" -maxdepth 1 -name 'encode-qrcode.*' -print -quit) ]]
printf '%s' 'reload cleanup' | "$QR_TEST_ENCODER" --type=PNG -o "$fixture/expected.png"
cmp "$fixture/expected.png" "$fixture/clipboard"
kill -TERM "$reload_pid"
wait "$reload_pid" || true
reload_pid=''
! rg -q 'TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/reload-log"
printf 'PASS: config reload clears the in-memory preview while preserving copied bytes\n'
