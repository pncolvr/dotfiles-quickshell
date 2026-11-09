#!/usr/bin/env bash
# Drop-in replacement for `code`: when the arguments contain `--profile NAME` and a
# data dir was seeded for NAME (see seed.sh), VS Code runs in that isolated data dir
# with its own sign-ins. Otherwise the arguments go to `code` unchanged.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=vscode-profiles.sh
source "$here/vscode-profiles.sh"

code=${VSCODE_PROFILES_CODE:-code}
profile=
explicit_dir=0
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    case ${args[i]} in
        --) break ;;
        --profile) profile=${args[i + 1]:-} ;;
        --profile=*) profile=${args[i]#*=} ;;
        --user-data-dir | --user-data-dir=*) explicit_dir=1 ;;
    esac
done

if [[ -n $profile && $explicit_dir == 0 ]] && dir=$(vscode_profile_dir "$profile") && [[ -d $dir/User ]]; then
    exec "$code" --user-data-dir "$dir" "$@"
fi
exec "$code" "$@"
