#!/usr/bin/env bash
# Exercise Quickshell's real config scanner/module loader, not file-URL imports.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

if [[ ${1:-} == --run ]]; then
    startup_test_dir=$2
    startup_entry="$startup_test_dir/config/shell.qml"
    output=$(timeout 10 qs -p "$startup_entry" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
    if [[ $output != *'PASS: full shell startup'* \
        || $output == *'Failed to load configuration'* \
        || $output == *'Binding loop detected'* \
        || $output == *'TypeError:'* || $output == *'ReferenceError:'* ]]; then
        printf '%s\n' "$output" >&2
        exit 1
    fi
    printf 'PASS: full shell startup\n'
    exit 0
fi

startup_test_display=${WAYLAND_DISPLAY:?A running Wayland session is required}
startup_test_runtime=${XDG_RUNTIME_DIR:?A Wayland runtime directory is required}
startup_test_dir=$(mktemp -d /tmp/quickshell-startup-test.XXXXXX)
trap 'rm -rf -- "$startup_test_dir"' EXIT
mkdir -p "$startup_test_dir/config/data" "$startup_test_dir/bin"
mkdir -m 700 "$startup_test_dir/runtime"
cp -R -- "$project_root/shell.qml" "$project_root/Bar.qml" "$project_root/bar" \
    "$project_root/config" "$project_root/modules" "$project_root/services" \
    "$project_root/theme" "$startup_test_dir/config/"

# Only startup commands are stubbed; all module registrations and QML are copied unchanged.
python3 - "$startup_test_dir/config" <<'PY'
import pathlib
import sys
config = pathlib.Path(sys.argv[1])
entry = config / 'shell.qml'
text = entry.read_text().replace('import Quickshell', 'import QtQuick\nimport Quickshell', 1)
end = text.rfind('}')
text = text[:end] + '''
  Timer {
    interval: 500
    running: true
    onTriggered: {
      console.log("PASS: full shell startup")
      Qt.quit()
    }
  }
''' + text[end:]
entry.write_text(text)
settings = config / 'config/Config.qml'
settings.write_text(settings.read_text().replace('`${home}/.config/zsh/scripts/status/manager.sh`', '"/usr/bin/false"'))
PY

cat > "$startup_test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
if [[ ${1:-} == clients ]]; then printf '[]\n'; else printf 'false\n'; fi
MOCK
for mock_command in ping solaar twitch canberra-gtk-play powerprofilesctl; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "$startup_test_dir/bin/$mock_command"
done
chmod +x "$startup_test_dir/bin/"*
cat > "$startup_test_dir/bus.conf" <<'BUS'
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

export QT_QPA_PLATFORM=wayland XDG_RUNTIME_DIR="$startup_test_dir/runtime"
export XDG_DATA_HOME="$startup_test_dir/data" XDG_CACHE_HOME="$startup_test_dir/cache"
export PATH="$startup_test_dir/bin:$PATH"
unset HYPRLAND_INSTANCE_SIGNATURE QS_NOTIFICATIONS_NATIVE
if [[ $startup_test_display == /* ]]; then export WAYLAND_DISPLAY="$startup_test_display";
else export WAYLAND_DISPLAY="$startup_test_runtime/$startup_test_display"; fi
dbus-run-session --config-file "$startup_test_dir/bus.conf" -- bash "$project_root/tests/notifications/startup.sh" --run "$startup_test_dir"
