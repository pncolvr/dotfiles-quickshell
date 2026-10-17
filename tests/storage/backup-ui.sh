#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-backup-ui.XXXXXXXX)
qs_pid=''
trap 'if [[ -n $qs_pid ]]; then kill "$qs_pid" 2>/dev/null || true; wait "$qs_pid" 2>/dev/null || true; fi; rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime" "$fixture/keyring" "$fixture/bin"
mkdir -p "$fixture/locations/project-present" "$fixture/locations/directory-present"
cat > "$fixture/fix-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$BACKUP_UI_DIRECTORY/locations/"{source,project-missing,directory-missing}
printf '{}' > "$BACKUP_UI_DIRECTORY/locations/project-present/test.code-workspace"
SH
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
mkdir -p "$fixture/tests/storage"
cp "$repo/tests/storage/backup-smoke.qml" "$fixture/tests/storage/"
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/bin/secret-tool" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
    search) for item in "$BACKUP_UI_DIRECTORY/keyring/"*.json; do [[ -f $item ]] || continue; printf '[item]\nsecret = '; cat "$item"; printf '\n'; done ;;
    store) cat > "$BACKUP_UI_DIRECTORY/keyring/${!#}.json" ;;
    clear) rm -f -- "$BACKUP_UI_DIRECTORY/keyring/${!#}.json" ;;
    *) exit 1 ;;
esac
MOCK
cat > "$fixture/bin/wl-copy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$BACKUP_UI_DIRECTORY/copy-args"
cat > "$BACKUP_UI_DIRECTORY/copied"
MOCK
chmod +x "$fixture/bin/"*
export BACKUP_UI_DIRECTORY=$fixture XDG_RUNTIME_DIR=$fixture/runtime XDG_DATA_HOME=$fixture/local XDG_CACHE_HOME=$fixture/cache
export PATH="$fixture/bin:$PATH" QT_QPA_PLATFORM=offscreen
sed 's@"../../src/@"src/@g' "$repo/tests/storage/backup-smoke.qml" > "$fixture/shell.qml"
timeout 50 qs -p "$fixture" > "$fixture/ui.log" 2>&1 || { cat "$fixture/ui.log"; exit 1; }
if ! rg -q 'PASS: backup private prompt' "$fixture/ui.log" || rg -q 'BACKUP FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/ui.log"; then
    cat "$fixture/ui.log"
    exit 1
fi
rg 'PASS:' "$fixture/ui.log"
[[ $(cat "$fixture/copy-args") == $'--sensitive\n--type\ntext/plain;charset=utf-8' && $(stat -c %s "$fixture/copied") == 32 ]]
cat > "$fixture/shell.qml" <<'QML'
import Quickshell
import "src/services"
Scope { readonly property bool loadBackup: BackupService.busy }
QML
qs -p "$fixture" > "$fixture/ipc.log" 2>&1 &
qs_pid=$!
ready=false
for ((attempt=0; attempt<100; attempt++)); do
    if qs ipc -p "$fixture" show 2>/dev/null | rg -q 'create'; then ready=true; break; fi
    sleep 0.05
done
[[ $ready == true ]] || { cat "$fixture/ipc.log"; exit 1; }
qs ipc -p "$fixture" call backup status | jq -e '.report.warningCount == 5 and .report.counts == {directories:1,sources:1,projects:1,workspaces:1}' >/dev/null
[[ $(qs ipc -p "$fixture" call backup create "$fixture/ipc.7z") == true ]]
qs ipc -p "$fixture" call backup status | jq -e '.prompting and (.busy | not)' >/dev/null
[[ $(qs ipc -p "$fixture" call backup create "$fixture/second.7z") == false ]]
[[ ! -e $fixture/ipc.7z ]]
printf 'PASS: real backup IPC, import report survives fresh shell, status and overlapping prompt refusal\n'
