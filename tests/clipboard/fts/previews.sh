#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-preview.XXXXXXXX)
server_pid=''; qs_pid=''; original_focus=''
cleanup() {
    for pid in "$qs_pid" "$server_pid"; do [[ -z $pid ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; done
    rm -rf -- "$fixture"
    if [[ $original_focus =~ ^0x[0-9a-fA-F]+$ ]]; then hyprctl dispatch "hl.dsp.focus({ window = \"address:$original_focus\" })" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
# Snapshot sources: checkout edits must not hot-reload a running QtTest wait.
tar -C "$root_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/previews.qml" > "$fixture/shell.qml"
magick -size 1920x1080 pattern:checkerboard "$fixture/landscape.png"
magick -size 600x1800 gradient:red-blue "$fixture/portrait.jpg"
magick -size 8x4 xc:blue "$fixture/tiny.png"
magick -size 800x600 xc:none -fill red -draw 'circle 400,300 400,100' "$fixture/transparent.webp"
for extension in gif bmp tiff; do magick -size 480x320 gradient:green-blue "$fixture/sample.$extension"; done
magick -size 6000x4000 gradient:white-black "$fixture/large.png"
for number in {0..7}; do ln "$fixture/large.png" "$fixture/held-$number.png"; done
printf 'invalid synthetic image' > "$fixture/corrupt.png"
export PREVIEW_TEST_DIRECTORY="$fixture"
cat > "$fixture/serve.sh" <<'SERVER'
#!/usr/bin/env bash
while IFS= read -r line; do [[ $line != $'\r' && -n $line ]] || break; done
sleep 0.4
printf 'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: %s\r\nConnection: close\r\n\r\n' "$(stat -c %s "$PREVIEW_TEST_DIRECTORY/landscape.png")"
cat "$PREVIEW_TEST_DIRECTORY/landscape.png"
SERVER
port=$(shuf -i 30000-45000 -n 1)
socat "TCP4-LISTEN:$port,bind=127.0.0.1,reuseaddr,fork" "EXEC:bash $fixture/serve.sh" > "$fixture/server.log" 2>&1 & server_pid=$!
export PREVIEW_TEST_SLOW_URL="http://127.0.0.1:$port/slow.png"
for ((attempt=0;attempt<40;attempt++)); do
    if curl --noproxy '*' -fsS --max-time 2 "$PREVIEW_TEST_SLOW_URL" -o /dev/null 2>/dev/null; then break; fi
    sleep 0.05
 done
kill -0 "$server_pid"
platform=offscreen; display=${WAYLAND_DISPLAY:-}; scales=(1 1.25 2)
if [[ ${PREVIEW_NATIVE:-0} == 1 ]]; then
    platform=wayland
    original_focus=$(hyprctl activewindow -j | jq -r '.address // ""')
fi
[[ -z $display || $display == /* ]] || display=${XDG_RUNTIME_DIR:?}/$display
for scale in "${scales[@]}"; do
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
        QT_QPA_PLATFORM="$platform" QT_SCALE_FACTOR="$scale" WAYLAND_DISPLAY="$display" \
        timeout 45 qs -p "$fixture" > "$fixture/log" 2>&1 & qs_pid=$!
    peak=0
    while kill -0 "$qs_pid" 2>/dev/null; do
        # timeout is the parent; measure the renderer, not the wrapper.
        child=$(pgrep -P "$qs_pid" | head -n 1 || true)
        if [[ -n $child && -r /proc/$child/status ]]; then
            rss=$(awk '$1=="VmRSS:" {print $2}' "/proc/$child/status" 2>/dev/null || true)
            [[ -z $rss ]] || ((rss <= peak)) || peak=$rss
        fi
        sleep 0.05
    done
    result=0; wait "$qs_pid" || result=$?; qs_pid=''
    ((result==0)) || { cat "$fixture/log"; exit 1; }
    rg 'PASS:|PREVIEW METRICS|NAVIGATION METRICS' "$fixture/log"
    if ! rg -q 'PASS: image formats' "$fixture/log" || rg -q 'PREVIEW FAIL:|FAIL!|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
    printf 'PREVIEW peak_rss_kib=%s scale=%s platform=%s\n' "$peak" "$scale" "$platform"
    # Codec working buffers/allocator arenas can exceed the requested decoded
    # viewport. The QML fixture checks growth between repeated navigation batches;
    # this ceiling additionally guards runaway allocation in the 24 MP PNG fixture.
    ((peak > 0 && peak < 900000)) || { printf 'Preview renderer exceeded the synthetic 900 MB ceiling\n' >&2; exit 1; }
done
