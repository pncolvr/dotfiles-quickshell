#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
scan_test_dir=$(mktemp -d /tmp/quickshell-project-scan.XXXXXXXX)
trap 'rm -rf -- "$scan_test_dir"' EXIT
mkdir -p "$scan_test_dir/home/.ssh"
printf 'Include "%s/home/.ssh/hosts"\n' "$scan_test_dir" > "$scan_test_dir/home/.ssh/config"
printf 'Host github-*\n    HostName github.com\n' > "$scan_test_dir/home/.ssh/hosts"
mkdir -p "$scan_test_dir/repos/banana/nested" "$scan_test_dir/repos/banana/.config/Code" "$scan_test_dir/repos/potato" "$scan_test_dir/repos/tomato" "$scan_test_dir/home/config folder" "$scan_test_dir/empty root"
printf '{}' > "$scan_test_dir/repos/banana/nested/Nested.code-workspace"
printf '{}' > "$scan_test_dir/repos/banana/.config/Code/Excluded.code-workspace"
git -C "$scan_test_dir/repos/banana" init -q
git -C "$scan_test_dir/repos/banana" -c user.name=Test -c user.email=test@example.test -c commit.gpgsign=false commit --allow-empty -qm initial
git -C "$scan_test_dir/repos/banana" remote add origin git@github-work:example/banana.git
git -C "$scan_test_dir/repos/banana" worktree add --detach -q "$scan_test_dir/worktree"
git -C "$scan_test_dir/repos/tomato" init -q
git init --bare -q "$scan_test_dir/home/.cfg"
printf test > "$scan_test_dir/home/config folder/config"
git --git-dir="$scan_test_dir/home/.cfg" --work-tree="$scan_test_dir/home" add 'config folder/config'
git --git-dir="$scan_test_dir/home/.cfg" remote add origin ssh://git@github-personal/example/config.git
request=$(jq -cn --arg directory "$scan_test_dir" '{sources:[
    {path:($directory + "/repos"),kind:"root",category:"work"},
    {path:($directory + "/worktree"),kind:"folder",category:"personal"},
    {path:($directory + "/home/config folder"),kind:"folder",category:"personal"},
    {path:($directory + "/empty root"),kind:"root",category:"personal"},
    {path:($directory + "/missing"),kind:"folder",category:"work"}
],sshConfig:($directory + "/home/.ssh/config"),workspaceExclusions:["*/.config/Code/*"],dotfilesGitDirectory:($directory + "/home/.cfg"),dotfilesWorkTree:($directory + "/home")}')
result=$(bash "$project_root/src/services/projects/scan.sh" scan <<< "$request")
jq -e '.sources[0].projects | length == 3 and any(.name == "banana" and .category == "work" and .url == "https://github.com/example/banana" and (.workspaces | length == 1) and .workspaces[0].name == "Nested") and any(.name == "potato" and .url == "") and any(.name == "tomato" and .url == "")' <<< "$result" >/dev/null
jq -e '.sources[1].projects[0].url == "https://github.com/example/banana" and .sources[2].projects[0].url == "https://github.com/example/config" and .sources[3].projects == [] and .sources[3].error == "" and (.sources[4].error | length) > 0' <<< "$result" >/dev/null
git -C "$scan_test_dir/repos/banana" remote set-url origin ssh://git@git.example.test:2222/example/banana.git
result=$(bash "$project_root/src/services/projects/scan.sh" scan <<< "$request")
jq -e '.sources[0].projects[] | select(.name == "banana") | .url == "https://git.example.test/example/banana"' <<< "$result" >/dev/null
request=$(jq '.sshConfig += ".missing"' <<< "$request")
result=$(bash "$project_root/src/services/projects/scan.sh" scan <<< "$request")
jq -e '.sources[2].projects[0].url == "https://github-personal/example/config"' <<< "$result" >/dev/null
printf 'PASS: scanner roots, non-Git/no-origin folders, worktrees, bare dotfiles, SSH aliases, recursive workspaces, exclusions, empty and missing roots\n'
