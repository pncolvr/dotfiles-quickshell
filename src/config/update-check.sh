#!/usr/bin/env bash
# Refreshes the AUR/pacman update cache consumed by UpdatesService.
set -uo pipefail
export LC_ALL=C

# User cron (crontab -e); no root database-sync job is needed.
# Requires pacman-contrib (checkupdates), yay and util-linux (flock).
# 0 * * * * /home/pncolvr/.config/quickshell/src/config/update-check.sh

# pacman hook
# /etc/pacman.d/hooks/95-quickshell-updates.hook
# [Trigger]
# Operation = Install
# Operation = Upgrade
# Operation = Remove
# Type = Package
# Target = *

# [Action]
# Description = Updating Quickshell package update cache...
# When = PostTransaction
# Exec = /usr/bin/sudo -u pncolvr -i /home/pncolvr/.config/quickshell/src/config/update-check.sh
# Depends = sudo

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
user_home="${HOME:-/home/pncolvr}"
cache_dir="$user_home/.cache/quickshell"
cache_file="$cache_dir/updates.cache"

mkdir -p "$cache_dir" || exit 1
exec 9>"$cache_dir/updates.lock" || exit 1
# Cron, pacman hooks and the shell can request a check at the same time.
flock -n 9 || exit 0
# Remove abandoned files from older/interrupted runs, leaving recent files alone.
find "$cache_dir" -maxdepth 1 -type f \( -name 'updates.cache.??????' -o -name 'updates.err.??????' \) -mmin +60 -delete

tmp_file="$(mktemp "$cache_dir/updates.cache.XXXXXX" 2>/dev/null)" || exit 1
err_file=""
trap 'rm -f "$tmp_file" "$err_file"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
err_file="$(mktemp "$cache_dir/updates.err.XXXXXX" 2>/dev/null)" || exit 1

fail() {
    printf 'Update check failed: %s\n' "$1" >&2
    [[ ! -s "$err_file" ]] || cat "$err_file" >&2
    qs ipc call updates schedule 9>&- 2>/dev/null || true
    exit 1
}

# Refresh a private database, without changing /var/lib/pacman or needing sudo.
export CHECKUPDATES_DB="$cache_dir/updates.db"
repo_updates="$(checkupdates --nocolor 2>"$err_file")"
repo_status=$?
if (( repo_status != 0 )) && ! { (( repo_status == 2 )) && [[ ! -s "$err_file" && -z "$repo_updates" ]]; }; then
    fail 'could not query repository updates.'
fi

aur_updates="$(yay -Qua --color never 2>"$err_file")"
yay_status=$?

# Only the documented empty exit-1 response means there are no updates.
if (( yay_status != 0 )) && ! { (( yay_status == 1 )) && [[ ! -s "$err_file" && -z "$aur_updates" ]]; }; then
    fail 'could not query AUR updates.'
fi
raw_updates="$(printf '%s\n' "$repo_updates" "$aur_updates" | sed '/^[[:space:]]*$/d')"

if [[ -z "$raw_updates" ]]; then
    : > "$tmp_file"
else
    mapfile -t names < <(awk '{print $1}' <<< "$raw_updates")

    # Query the same database used for versions; AUR rows use the fallback below.
    si_output="$(pacman --dbpath "$CHECKUPDATES_DB" -Si --color never "${names[@]}" 2>/dev/null)"

    declare -A repo_of arch_of
    name=""; repo_of_tmp=""
    while IFS= read -r line; do
        case "$line" in
            Repository*) repo_of_tmp="$(awk -F': ' '{print $2}' <<< "$line")" ;;
            Name*) name="$(awk -F': ' '{print $2}' <<< "$line")"; [[ -v repo_of[$name] ]] || repo_of["$name"]="$repo_of_tmp" ;;
            Architecture*) [[ -v arch_of[$name] ]] || arch_of["$name"]="$(awk -F': ' '{print $2}' <<< "$line")" ;;
        esac
    done <<< "$si_output"

    while IFS= read -r line; do
        read -r pkg old arrow new extra <<< "$line"
        [[ -n $pkg && -n $old && $arrow == '->' && -n $new ]] || exit 1
        # Yay 13 appends an AUR update age, e.g. "[1d]"; it is not a version.
        [[ -z $extra || $extra =~ ^\[([0-9]+[a-z]+)+\]$ ]] || exit 1
        repo="${repo_of[$pkg]:-aur}"
        arch="${arch_of[$pkg]:-x86_64}"
        printf "%s %s %s %s %s\n" "$repo" "$arch" "$pkg" "$old" "$new"
    done <<< "$raw_updates" | sort > "$tmp_file" || {
        fail 'invalid package update row.'
    }
fi
# Publish both empty and populated snapshots with one atomic rename.
mv -f -- "$tmp_file" "$cache_file" || {
    fail 'could not publish the update cache.'
}
qs ipc call updates reload 9>&- 2>/dev/null || true
exit 0
