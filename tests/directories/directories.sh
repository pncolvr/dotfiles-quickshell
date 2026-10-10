#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-directories.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/config/data" "$test_dir/bin" "$test_dir/home/.config/zsh/scripts/status" "$test_dir/home/banana folder"
mkdir -m700 "$test_dir/runtime"
ln -s "$project_root/src" "$test_dir/config/src"
ln -s "$test_dir/home/banana folder" "$test_dir/folder-link"
printf '#!/bin/sh\nprintf "personal\\n"\n' > "$test_dir/home/.config/zsh/scripts/status/manager.sh"
printf '#!/bin/sh\nprintf "[]\\n"\n' > "$test_dir/bin/hyprctl"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/ping"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/solaar"
cat > "$test_dir/bin/pcmanfm-qt" <<'MOCK'
#!/usr/bin/env bash
jq -cn --args '$ARGS.positional' -- "$@" >> "$DIRECTORY_TEST_DIR/actions"
MOCK
chmod +x "$test_dir/bin/"* "$test_dir/home/.config/zsh/scripts/status/manager.sh"
export DIRECTORY_TEST_DIR="$test_dir" HOME="$test_dir/home" PATH="$test_dir/bin:$PATH"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1
resolver="$project_root/src/services/files/resolve-folder.sh"
bash "$resolver" '~/banana folder' | jq -e --arg path "$HOME/banana folder" '.path == $path' >/dev/null
bash "$resolver" "$test_dir/folder-link" | jq -e --arg path "$HOME/banana folder" '.path == $path' >/dev/null
bash "$resolver" 'computer:///' | jq -e '.path == "computer:///" and .name == "Computer"' >/dev/null
if bash "$resolver" "$test_dir/missing" >/dev/null 2>&1; then exit 1; fi
touch "$test_dir/plain-file"
if bash "$resolver" "$test_dir/plain-file" >/dev/null 2>&1; then exit 1; fi
cat > "$test_dir/config/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/directories/directories-smoke.qml" } }
QML
for phase in setup restart; do
    output=$(DIRECTORY_TEST_PHASE="$phase" timeout 25 qs -p "$test_dir/config/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *"PASS: directories $phase"* && $output != *'DIRECTORY FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop detected'* ]]
done
jq -se 'any(.[]; . == ["trash:///"])' "$test_dir/actions" >/dev/null
[[ $(sqlite3 "$test_dir/config/data/quickshell.db" 'PRAGMA user_version; PRAGMA integrity_check;') == $'9\nok' ]]
printf 'PASS: native directories CRUD, virtual locations, status filtering, focused shortcuts and restart persistence\n'
