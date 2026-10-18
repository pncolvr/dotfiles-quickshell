#!/usr/bin/env bash
# Installs user-owned integration files only; never changes default associations.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
if [[ ${1:-} == --help ]]; then
    printf 'Usage: bash integrations/browser/install.sh [BROWSER [ARG ...]]\n'
    printf 'With no arguments, choose an installed browser and optional extra arguments.\n'
    printf 'Example: bash integrations/browser/install.sh qutebrowser\n'
    printf 'The literal command is used when Quickshell is stopped. No routing or history then.\n'
    exit 0
fi
staging=$(mktemp -d)
trap 'rm -rf -- "$staging"' EXIT
if [[ $# == 0 ]]; then
    if ! env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        QS_BROWSER_CHOICES_FILE="$staging/choices.json" \
        timeout -k 1 10 qs --no-color -p "$repo/src/services/browser/desktop/Discovery.qml" >/dev/null 2>&1; then
        printf 'Browser discovery failed. Supply BROWSER [ARG ...] explicitly.\n' >&2; exit 2
    fi
    choices=$(cat "$staging/choices.json")
    jq -e 'type=="array" and length>0' <<< "$choices" >/dev/null || {
        printf 'No available desktop browsers found. Supply BROWSER [ARG ...] explicitly.\n' >&2; exit 2;
    }
    jq -r 'to_entries[] | "\(.key+1)) \(.value.name) [\(.value.id)]"' <<< "$choices"
    read -r -p 'Browser number: ' selection
    [[ $selection =~ ^[1-9][0-9]*$ && ${#selection} -le 6 ]] || exit 2
    selected=$(jq -ce --argjson index "$((10#$selection-1))" '.[$index] | select(.!=null)' <<< "$choices")
    mapfile -d '' -t selected_argv < <(jq -j '.command[] | select(.!="{url}") | ., "\u0000"' <<< "$selected")
    printf 'Optional extra arguments, one per line (for example --profile-directory=Personal).\nFinish with an empty line; arguments are literal, without shell quotes.\n'
    while IFS= read -r -p 'Argument: ' argument && [[ -n $argument ]]; do selected_argv+=("$argument"); done
    set -- "${selected_argv[@]}"
fi
case ${1##*/} in xdg-open|quickshell-browser|default-browser.sh) printf 'Choose a concrete fallback browser.\n' >&2; exit 2;; esac
command -v "$1" >/dev/null || { printf 'Fallback browser executable not found.\n' >&2; exit 2; }
fallback=$(jq -nc --args '$ARGS.positional' -- "$@")
launcher="$HOME/.local/bin/quickshell-browser"
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p -- "${launcher%/*}" "$applications"
printf '#!/usr/bin/env bash\nexec bash %q open --fallback %q -- "$@"\n' \
    "$repo/src/services/browser/browser.sh" "$fallback" > "$staging/launcher"
# Both xdg-settings and generic xdg-open mishandle quoted executable paths.
# A launcher name on PATH also works when the user's home contains spaces.
cp -- "$repo/integrations/browser/quickshell-browser.desktop" "$staging/desktop"
install -m755 -- "$staging/launcher" "$launcher"
install -m644 -- "$staging/desktop" "$applications/quickshell-browser.desktop"
if command -v update-desktop-database >/dev/null; then update-desktop-database "$applications"; fi
printf 'Installed %s and %s/quickshell-browser.desktop\nDefault associations were not changed.\n' "$launcher" "$applications"
if [[ $(command -v quickshell-browser || true) != "$launcher" ]]; then
    printf 'Add %s to your desktop session PATH so the desktop entry can find quickshell-browser.\n' "${launcher%/*}"
fi
