#!/usr/bin/env bash
# Private-bus lifecycle only: no Quickshell windows or desktop input.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-session-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
source "$repo/src/services/processes/process-identity.sh"
if [[ ${1:-} == --portal ]]; then
    # Keep normal activation so this also exercises the installed GTK/Hypr backends.
    cat > "$fixture/command.sh" <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail
gdbus call --session --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.Settings.ReadAll '[]' > /dev/null
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListNames | tr "'" '\n' | awk '
    /^org\.freedesktop\.(impl\.)?portal\./ || /^org\.gtk\.vfs\./ || $0 == "ca.desrt.dconf"
' | while IFS= read -r name; do
    reply=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.GetConnectionUnixProcessID "$name")
    [[ $reply =~ ^\(uint32\ ([1-9][0-9]*),\)$ ]]
    pid=${BASH_REMATCH[1]}
    start=$(process_identity "$pid")
    printf '%s\t%s\n' "$pid" "$start" >> "$SESSION_TEST_DIR/services"
done
COMMAND
    # Functions must be available to the command's pipeline subprocesses too.
    export -f process_identity
    export SESSION_TEST_DIR="$fixture"
    ulimit -c 0
    if ! dbus-run-session -- bash "$repo/tests/runner/session.sh" bash "$fixture/command.sh" > "$fixture/log" 2>&1; then
        cat "$fixture/log"; exit 1
    fi
    [[ -s $fixture/services ]]
    while IFS=$'\t' read -r pid start; do
        if process_alive "$pid" "$start" "$PROCESS_BOOT_ID"; then cat "$fixture/log"; exit 1; fi
    done < "$fixture/services"
    if rg -q "A connection to the bus can't be made|Disconnected from pollfd|Segmentation fault|No such process|\[ERR\].*Terminated" "$fixture/log"; then
        cat "$fixture/log"; exit 1
    fi
    printf 'PASS: installed portals activate normally and stop before their private bus closes, without teardown errors\n'
    exit
fi
[[ $# == 0 ]] || { printf 'Usage: bash tests/runner/session-test.sh [--portal]\n' >&2; exit 2; }
mkdir "$fixture/services"
cat > "$fixture/bus.conf" <<CONFIG
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <servicedir>$fixture/services</servicedir>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
CONFIG
cat > "$fixture/service.sh" <<'SERVICE'
#!/usr/bin/env bash
set -uo pipefail
directory=${BASH_SOURCE[0]%/*}
dbus-test-tool echo --name="$1" > /dev/null 2>&1 &
pid=$!
printf '%s\n' "$pid" > "$directory/$1.pid"
status=0
wait "$pid" || status=$?
printf '%s\n' "$status" > "$directory/$1.exit"
SERVICE
for name in org.freedesktop.portal.Desktop org.freedesktop.impl.portal.desktop.mock org.example.SessionControl; do
    cat > "$fixture/services/$name.service" <<SERVICE
[D-BUS Service]
Name=$name
Exec=/bin/bash $fixture/service.sh $name
SERVICE
done
cat > "$fixture/command.sh" <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail
for name in org.freedesktop.portal.Desktop org.freedesktop.impl.portal.desktop.mock org.example.SessionControl; do
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.StartServiceByName "$name" 0 > /dev/null
done
exit 23
COMMAND
result=0
dbus-run-session --config-file "$fixture/bus.conf" -- bash "$repo/tests/runner/session.sh" \
    bash "$fixture/command.sh" > "$fixture/log" 2>&1 || result=$?
[[ $result == 23 ]] || { cat "$fixture/log"; exit 1; }
for ((attempt=0; attempt<100; attempt++)); do
    [[ -s $fixture/org.freedesktop.portal.Desktop.exit && -s $fixture/org.freedesktop.impl.portal.desktop.mock.exit \
        && -s $fixture/org.example.SessionControl.exit ]] && break
    sleep 0.025
done
[[ $(cat "$fixture/org.freedesktop.portal.Desktop.exit") == 143 ]]
[[ $(cat "$fixture/org.freedesktop.impl.portal.desktop.mock.exit") == 143 ]]
[[ $(cat "$fixture/org.example.SessionControl.exit") != 143 ]]
printf 'PASS: private session retains activation, stops its portal services, leaves unrelated services unsignalled and preserves command failure\n'

# A shell between dbus-run-session and the wrapper is not the wrapper's own bus.
result=0
dbus-run-session --config-file "$fixture/bus.conf" -- bash -c \
    'bash "$1" true; result=$?; exit "$result"' shell "$repo/tests/runner/session.sh" > "$fixture/refused.log" 2>&1 || result=$?
[[ $result == 2 ]]
rg -q 'requires its own dbus-run-session' "$fixture/refused.log"
printf 'PASS: session wrapper refuses cleanup on a bus it does not own\n'
