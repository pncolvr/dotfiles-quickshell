#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash "$project_root/tests/notifications/encode-image.sh"
notification_test_display="${WAYLAND_DISPLAY:-}"
notification_test_runtime="${XDG_RUNTIME_DIR:-}"
test_dir=$(mktemp -d /tmp/quickshell-notifications-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/config/data" "$test_dir/bin" "$test_dir/data" "$test_dir/cache"
mkdir -p "$test_dir/config/services/notifications"
cp -- "$project_root/services/notifications/encode-image.sh" "$test_dir/config/services/notifications/encode-image.sh"
mkdir -m 700 "$test_dir/runtime"
cat > "$test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == clients ]]; then printf '[]\n'; else printf 'false\n'; fi
MOCK
cat > "$test_dir/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cat > "$test_dir/bin/xdg-open" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$NOTIFICATION_TEST_DIR/opened-urls"
MOCK
chmod +x "$test_dir/bin/"*
python3 - "$project_root" "$test_dir" <<'PY'
import pathlib
import sys
project, target = map(pathlib.Path, sys.argv[1:])
text = (project / 'tests/notifications/notification-smoke.qml').read_text()
text = text.replace('@NATIVE_WINDOWS@', (project / 'tests/notifications/notification-wayland-smoke.qml').as_uri())
for relative in ('services', 'modules/system/notifications'):
    text = text.replace(f'import "../../{relative}"', f'import "{(project / relative).as_uri()}"')
(target / 'config/shell.qml').write_text(text)
PY
cat > "$test_dir/bus.conf" <<'BUS'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
BUS
export QT_QPA_PLATFORM=offscreen
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache"
export NOTIFICATION_TEST_DIR="$test_dir" PATH="$test_dir/bin:$PATH"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE QS_NOTIFICATIONS_NATIVE
if [[ ${1:-} == --wayland ]]; then
    [[ -n $notification_test_display && -n $notification_test_runtime ]]
    export QT_QPA_PLATFORM=wayland NOTIFICATION_TEST_WAYLAND=1
    if [[ $notification_test_display == /* ]]; then export WAYLAND_DISPLAY="$notification_test_display";
    else export WAYLAND_DISPLAY="$notification_test_runtime/$notification_test_display"; fi
fi
dbus-run-session --config-file "$test_dir/bus.conf" -- python3 "$project_root/tests/notifications/notifications.py"
