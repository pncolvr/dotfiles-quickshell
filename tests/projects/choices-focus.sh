#!/usr/bin/env bash
# Brief native focus check with synthetic projects and a mocked editor; no cursor movement.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'SKIP: project choices focus check requires a native Wayland session\n'
    exit 0
fi
desktop_runtime=${XDG_RUNTIME_DIR:?}
display=$WAYLAND_DISPLAY
[[ $display == /* ]] || display=$desktop_runtime/$display
fixture=$(mktemp -d /tmp/qspc.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/r"
ln -s "$desktop_runtime/hypr" "$fixture/r/hypr"
mkdir -p "$fixture/bin" "$fixture/projects/Plain"
for name in 'Alpha Project' 'Beta Project'; do
    mkdir -p "$fixture/projects/$name"
    printf '{}' > "$fixture/projects/$name/$name.code-workspace"
    printf '{}' > "$fixture/projects/$name/Excluded.code-workspace"
done
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/windowClass: "code"/windowClass: ""/' "$fixture/src/config/Config.qml"
cat > "$fixture/bin/code" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$PROJECT_CHOICES_TEST_DIR/actions"
MOCK
chmod +x "$fixture/bin/code"
sed 's@"../../src@"src@g' "$repo_dir/tests/projects/choices-focus.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display" XDG_RUNTIME_DIR="$fixture/r" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" PROJECT_CHOICES_TEST_DIR="$fixture" \
    PATH="$fixture/bin:$PATH" timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: native project choices' "$fixture/log" \
    || rg -q 'PROJECT CHOICES FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration|FAIL!' "$fixture/log"; then
    cat "$fixture/log"; exit 1
fi
[[ $(cat "$fixture/actions") == "$fixture/projects/Plain" ]]
rg 'PASS:' "$fixture/log"
