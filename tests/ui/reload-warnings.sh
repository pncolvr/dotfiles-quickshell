#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-reload-warnings.XXXXXXXX)
cleanup() {
    local result=$?
    if ((result != 0)); then cat "$fixture/log" >&2; fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/;s/twitchEnabled: true/twitchEnabled: false/;s/batteriesEnabled: true/batteriesEnabled: false/;s/workModeEnabled: true/workModeEnabled: false/' "$fixture/src/config/Config.qml"
# Exercise the production root's actual teardown callback, while keeping native
# panels and the live desktop out of this isolated engine-generation test.
python - "$project_root" "$fixture" <<'PY'
from pathlib import Path
import re
import sys
project, fixture = map(Path, sys.argv[1:])
shell = (project / "shell.qml").read_text()
handler = re.search(r"^  Component\.onDestruction: .+$", shell, re.M)
if handler is None:
    raise SystemExit("Missing shell generation cleanup")
test = (project / "tests/ui/reload-warnings.qml").read_text()
test = test.replace('"../../src', '"src').replace("// ROOT_DESTRUCTION_HANDLER", handler[0].strip())
(fixture / "shell.qml").write_text(test)
PY
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_NO_XDG_DESKTOP_PORTAL=1 \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout 12 qs -p "$fixture" > "$fixture/log" 2>&1
rg -q 'PASS: twenty tooltip generations' "$fixture/log"
! rg -q 'RELOAD WARNINGS FAIL|Unable to assign|Failed to load configuration|TypeError:|ReferenceError:|Binding loop' "$fixture/log"
printf 'PASS: tooltip references released before old-generation teardown across twenty reloads\n'
