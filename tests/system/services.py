#!/usr/bin/env python3
"""Run service regressions with private storage and mocked desktop commands."""
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def override_config(directory, values):
    path = directory / "src/config/Config.qml"
    source = path.read_text()
    for name, value in values.items():
        pattern = rf"(readonly property (?:var|int|bool) {name}: )[^\n]*"
        source, count = re.subn(pattern, lambda match: match[1] + value, source)
        assert count == 1, name
    path.write_text(source)


def run_qml(directory, fixture, phase=""):
    source = (ROOT / fixture).read_text().replace('"../../src', '"src')
    (directory / "shell.qml").write_text(source)
    environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_RUNTIME_DIR=str(directory / "runtime"), XDG_DATA_HOME=str(directory / "data"),
                       XDG_CACHE_HOME=str(directory / "cache"), SERVICES_TEST_PHASE=phase)
    result = subprocess.run(["qs", "-p", str(directory)], env=environment,
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    errors = ("SERVICES FAIL:", "Failed to load configuration", "TypeError:", "ReferenceError:", "Binding loop detected")
    assert result.returncode == 0 and "PASS:" in output and not any(error in output for error in errors), output
    for line in output.splitlines():
        if "PASS:" in line:
            print(line)


def fixture_directory(parent, name):
    directory = parent / name
    directory.mkdir()
    shutil.copytree(ROOT / "src", directory / "src", ignore=shutil.ignore_patterns("*.env", "hosts.json"))
    (directory / "data").mkdir()
    (directory / "runtime").mkdir(mode=0o700)
    (directory / "cache").mkdir()
    return directory


with tempfile.TemporaryDirectory(prefix="quickshell-services-test-", dir="/tmp") as temporary:
    parent = Path(temporary)
    clipboard = fixture_directory(parent, "clipboard")
    override_config(clipboard, {
        "clipboardMonitorEnabled": "false",
        "clipboardCommand": '["bash", Quickshell.shellPath("clipboard-helper.sh")]',
    })
    (clipboard / "clipboard-helper.sh").write_text('''#!/usr/bin/env bash
set -euo pipefail
directory=$(dirname "$0")
printf '%s\\n' "$1" >> "$directory/actions"
if [[ ${SERVICES_TEST_PHASE:-} == prune-failure && ! -f $directory/failed-once ]]; then
    touch "$directory/failed-once"
    exit 1
fi
exec bash "$directory/src/services/clipboard/clipboard.sh" "$@"
''')
    payload = clipboard / "data/clipboard" / ("a" * 64)
    payload.parent.mkdir()
    payload.write_bytes(b"retained payload")
    database = clipboard / "data/quickshell.db"
    with sqlite3.connect(database) as connection:
        connection.execute("PRAGMA user_version=999")
    run_qml(clipboard, "tests/clipboard/storage-smoke.qml", "database-failure")
    assert payload.read_bytes() == b"retained payload" and not (clipboard / "actions").exists()
    with sqlite3.connect(database) as connection:
        connection.execute("PRAGMA user_version=0")
    run_qml(clipboard, "tests/clipboard/storage-smoke.qml", "prune-failure")
    assert not payload.exists() and (clipboard / "actions").read_text().splitlines() == ["prune", "prune"]
    (clipboard / "actions").unlink()
    run_qml(clipboard, "tests/clipboard/storage-smoke.qml", "recovery")
    assert (clipboard / "actions").read_text().splitlines() == ["prune"]

    network = fixture_directory(parent, "network")
    override_config(network, {
        "networkCheckCommand": '["printf", "1\\n"]',
        "networkStatsCommand": '["printf", "eth0 1 1\\n"]',
        "networkConnectionsCommand": '["printf", "%s\\n", "wlan0:Cafe\\\\:Home\\\\\\\\Office:wifi:connected"]',
        "networkVpnCommand": '["printf", "%s\\n", "Work\\\\:VPN\\\\\\\\Office:vpn:activated"]',
        "networkProcessesCommand": '["true"]',
    })
    run_qml(network, "tests/system/network-smoke.qml")

    updates = fixture_directory(parent, "updates")
    override_config(updates, {
        "networkCheckCommand": '["printf", "0\\n"]',
        "updatesCheckCommand": '["bash", Quickshell.shellPath("update-snapshot.sh")]',
        "updatesRefreshCommand": '["true"]',
    })
    (updates / "update-snapshot.sh").write_text('''#!/usr/bin/env bash
counter_file="$(dirname "$0")/counter"
count=$(cat "$counter_file" 2>/dev/null || printf 0)
count=$((count + 1))
printf '%s' "$count" > "$counter_file"
case $count in
    1) printf 'core x86_64 linux 1 2\\nextra x86_64 example 1 2\\n' ;;
    2) printf 'extra x86_64 partial 1 2\\n'; exit 1 ;;
    3) printf 'extra x86_64 partial 1 2\\nbroken row\\n' ;;
    *) exit 0 ;;
esac
''')
    run_qml(updates, "tests/system/updates-smoke.qml")
