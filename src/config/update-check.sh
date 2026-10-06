#!/usr/bin/env bash
# Refreshes the AUR/pacman update cache consumed by UpdatesService.

# sudo cron
# 59 * * * * /usr/bin/yay -Sy --noconfirm >/dev/null 2>&1

# cron
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

mkdir -p "$cache_dir" || exit 0
tmp_file="$(mktemp "$cache_dir/updates.cache.XXXXXX" 2>/dev/null)" || exit 0
err_file="$(mktemp "$cache_dir/updates.err.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -f "$tmp_file" "$err_file"' EXIT

raw_updates="$(yay -Qu 2>"$err_file")"
yay_status=$?

# yay -Qu exits 1 with no stderr when there are simply no updates
if (( yay_status != 0 )) && [[ -s "$err_file" ]]; then
    qs ipc call updates schedule 2>/dev/null || true
    exit 0
fi

if [[ -z "$raw_updates" ]]; then
    : > "$cache_file"
else
    mapfile -t names < <(awk '{print $1}' <<< "$raw_updates")

    # single batched query instead of one yay -Si per package
    si_output="$(yay -Si "${names[@]}" 2>/dev/null)"

    declare -A repo_of arch_of
    name=""
    while IFS= read -r line; do
        case "$line" in
            Repository*) repo_of_tmp="$(awk -F': ' '{print $2}' <<< "$line")" ;;
            Name*) name="$(awk -F': ' '{print $2}' <<< "$line")"; repo_of["$name"]="$repo_of_tmp" ;;
            Architecture*) arch_of["$name"]="$(awk -F': ' '{print $2}' <<< "$line")" ;;
        esac
    done <<< "$si_output"

    while IFS= read -r line; do
        read -r pkg old arrow new _ <<< "$line"
        [[ "$arrow" == "->" ]] || continue
        repo="${repo_of[$pkg]:-aur}"
        arch="${arch_of[$pkg]:-x86_64}"
        printf "%s %s %s %s %s\n" "$repo" "$arch" "$pkg" "$old" "$new"
    done <<< "$raw_updates" | sort > "$tmp_file"
    cat "$tmp_file" > "$cache_file" 2>/dev/null || cp "$tmp_file" "$cache_file" 2>/dev/null || true
fi
qs ipc call updates reload 2>/dev/null || true
exit 0