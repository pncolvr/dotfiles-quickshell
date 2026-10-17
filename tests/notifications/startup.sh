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
cp -R -- "$project_root/shell.qml" "$project_root/src" "$startup_test_dir/config/"

# Only startup commands are stubbed; all module registrations and QML are copied unchanged.
awk '
    !imported && /import Quickshell/ { sub(/import Quickshell/, "import QtQuick\nimport Quickshell"); imported = 1 }
    { lines[NR] = $0; if ($0 ~ /^}$/) closing = NR }
    END {
        if (!closing || !imported) exit 1
        for (i = 1; i <= NR; i++) {
            if (i == closing) {
                print "  Timer {"
                print "    interval: 500"
                print "    running: true"
                print "    onTriggered: {"
                print "      console.log(\"PASS: full shell startup\")"
                print "      Qt.quit()"
                print "    }"
                print "  }"
            }
            print lines[i]
        }
    }
' "$startup_test_dir/config/shell.qml" > "$startup_test_dir/config/startup.qml"
mv -- "$startup_test_dir/config/startup.qml" "$startup_test_dir/config/shell.qml"

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
