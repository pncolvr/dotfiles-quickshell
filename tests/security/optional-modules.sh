#!/usr/bin/env bash
# Private configuration and synthetic helpers; no real secrets, windows or input.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-optional-modules.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime" "$fixture/home"
mkdir "$fixture/bin"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property bool totpEnabled:/property bool totpEnabled:/;s/readonly property bool vaultEnabled:/property bool vaultEnabled:/;s/workModeEnabled: true/workModeEnabled: false/;s/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '[]\n'
MOCK
chmod +x "$fixture/bin/hyprctl"
cat > "$fixture/totp-helper.sh" <<'MOCK'
#!/usr/bin/env bash
while IFS= read -r request; do
    action=$(jq -r .action <<< "$request")
    printf 'totp:%s\n' "$action" >> "$OPTIONAL_MODULES_CALLS"
    [[ $action != quit ]] || exit 0
    jq -nc --argjson now "$(date +%s)" '{type:"snapshot",timestamp:$now,expiresAt:($now+3600),period:3600,entries:[{id:"fixture",name:"Retained token",code:"123456",expiresAt:($now+3600)}]}'
done
MOCK
cat > "$fixture/src/services/vault/rbw-manager.sh" <<'MOCK'
#!/usr/bin/env bash
IFS= read -r request
printf 'vault:%s\n' "$(jq -r .action <<< "$request")" >> "$OPTIONAL_MODULES_CALLS"
printf '{"ok":true,"entries":[{"id":"fixture","name":"Retained entry","folder":"Test"}]}\n'
MOCK
node - "$fixture" <<'JS'
const fs=require('fs'),path=process.argv[2]+'/src/config/Config.qml';
let source=fs.readFileSync(path,'utf8');
source=source.replace(/readonly property var totpCommand: \[[\s\S]*?\n    \]/,
    'readonly property var totpCommand: ["bash", Quickshell.shellPath("totp-helper.sh")]');
fs.writeFileSync(path,source);
JS
sed 's@"../../src@"src@g' "$repo/tests/security/optional-modules.qml" > "$fixture/shell.qml"
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    HOME="$fixture/home" XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    PATH="$fixture/bin:$PATH" OPTIONAL_MODULES_CALLS="$fixture/calls" \
    timeout -k 2 15 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
if ! rg -q 'PASS: optional TOTP/Vault' "$fixture/log" || rg -q 'OPTIONAL MODULES FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
[[ $(sort "$fixture/calls") == $'totp:load\ntotp:load\ntotp:quit\ntotp:quit\nvault:list' ]] || { cat "$fixture/calls"; exit 1; }
rg 'PASS:' "$fixture/log"
