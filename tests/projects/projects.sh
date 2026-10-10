#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash "$project_root/tests/projects/scan.sh"
test_dir=$(mktemp -d /tmp/quickshell-projects.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/config/data" "$test_dir/bin" "$test_dir/repos/banana/nested" "$test_dir/repos/banana/.config/Code" "$test_dir/repos/potato" "$test_dir/single folder" "$test_dir/home/.config/zsh/scripts/status"
mkdir -m700 "$test_dir/runtime"
mkdir -p "$test_dir/no workspaces" "$test_dir/plain root/tomato" "$test_dir/empty root"
mkdir -p "$test_dir/home/.ssh"
printf 'Host github-personal\n    HostName github.com\n' > "$test_dir/home/.ssh/config"
ln -s "$project_root/src" "$test_dir/config/src"
printf '{}' > "$test_dir/repos/banana/Banana.code-workspace"
printf '{}' > "$test_dir/repos/banana/nested/Tomato.code-workspace"
printf '{}' > "$test_dir/repos/banana/.config/Code/Hidden.code-workspace"
printf '{}' > "$test_dir/single folder/Single.code-workspace"
git -C "$test_dir/repos/banana" init -q
git -C "$test_dir/repos/banana" remote add origin git@github-personal:example/banana.git
cat > "$test_dir/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
printf '[]\n'
MOCK
cat > "$test_dir/bin/code" <<'MOCK'
#!/usr/bin/env bash
jq -cn --args '$ARGS.positional' -- "$@" >> "$PROJECT_TEST_DIR/actions"
MOCK
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/ping"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/solaar"
printf '#!/bin/sh\nprintf "work\\n"\n' > "$test_dir/home/.config/zsh/scripts/status/manager.sh"
chmod +x "$test_dir/bin/"* "$test_dir/home/.config/zsh/scripts/status/manager.sh"
export PROJECT_TEST_DIR="$test_dir" PATH="$test_dir/bin:$PATH" HOME="$test_dir/home"
export XDG_RUNTIME_DIR="$test_dir/runtime" XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" QT_QPA_PLATFORM=offscreen QT_NO_XDG_DESKTOP_PORTAL=1
cat > "$test_dir/config/shell.qml" <<QML
import QtQuick
import Quickshell
Scope { Loader { source: "file://$project_root/tests/projects/projects-smoke.qml" } }
QML
for phase in setup restart missing; do
    if [[ $phase == restart ]]; then
        mkdir -p "$test_dir/repos/garlic"
        printf '{}' > "$test_dir/repos/banana/New.code-workspace"
        printf '{}' > "$test_dir/repos/banana/Optional.code-workspace"
    elif [[ $phase == missing ]]; then
        mv "$test_dir/repos" "$test_dir/repos-unavailable"
    fi
    output=$(PROJECT_TEST_PHASE="$phase" timeout 30 qs -p "$test_dir/config/shell.qml" 2>&1) || { printf '%s\n' "$output"; exit 1; }
    printf '%s\n' "$output"
    [[ $output == *"PASS: projects $phase"* && $output != *'PROJECT FAIL:'* && $output != *'TypeError:'* && $output != *'ReferenceError:'* && $output != *'Binding loop detected'* ]]
done
jq -se --arg path "$test_dir/repos/banana/Banana.code-workspace" 'any(.[]; . == [$path,"--profile","Personal"])' "$test_dir/actions" >/dev/null
[[ $(sqlite3 "$test_dir/config/data/quickshell.db" 'PRAGMA user_version; PRAGMA integrity_check;') == $'9\nok' ]]
# A missing source retains the last successful snapshot. No cache JSON is written.
[[ ! -e $XDG_CACHE_HOME/code_projects_${USER}.json ]]
printf 'PASS: project discovery, explicit categories, workspace choices, manual refresh, failed scans, native picker and restart persistence\n'
