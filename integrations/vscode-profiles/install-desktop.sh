#!/usr/bin/env bash
# Installs (or removes with --remove) one "Code (PROFILE)" app menu entry per
# profile, each launching code-profile.sh --profile PROFILE.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helpers=$(cd -- "$here/../../src/services/projects" && pwd)
# shellcheck source=../../src/services/projects/vscode-profiles.sh
source "$helpers/vscode-profiles.sh"

if [[ ${1:-} == -h || ${1:-} == --help || $# == 0 ]]; then
    printf 'Usage: bash integrations/vscode-profiles/install-desktop.sh [--remove] PROFILE ...\n'
    printf 'Writes ~/.local/share/applications/code-<slug>.desktop for each PROFILE.\n'
    [[ $# == 0 ]] && exit 2 || exit 0
fi
remove=0
[[ $1 == --remove ]] && { remove=1; shift; }
applications=${XDG_DATA_HOME:-$HOME/.local/share}/applications
mkdir -p -- "$applications"
for name in "$@"; do
    slug=$(vscode_profile_slug "$name") || { printf 'bad profile name %s\n' "$name" >&2; exit 1; }
    file=$applications/code-$slug.desktop
    if ((remove)); then rm -fv -- "$file"; continue; fi
    # Desktop Exec quoting is not shell quoting; refuse characters needing escapes.
    [[ $name =~ ^[A-Za-z0-9\ ._-]+$ && $helpers =~ ^[^\"\`\$\\%]+$ ]] \
        || { printf 'profile name or path has characters unsafe for Exec: %s\n' "$name" >&2; exit 1; }
    exec_line="bash \"$helpers/code-profile.sh\" --profile \"$name\""
    cat > "$file" <<EOF
[Desktop Entry]
Type=Application
Name=Code ($name)
Comment=Visual Studio Code with the $name account data dir
Exec=$exec_line %F
Icon=vscode
Categories=Development;IDE;TextEditor;
StartupNotify=true
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$exec_line --new-window %F
EOF
    printf 'wrote %s\n' "$file"
done
command -v update-desktop-database >/dev/null && update-desktop-database "$applications" 2>/dev/null || true
