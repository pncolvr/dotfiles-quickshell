#!/usr/bin/env bash
# Refreshes the AUR/pacman update cache consumed by UpdatesService.

export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
user_home="${HOME:-/home/pncolvr}"
cache_dir="$user_home/.cache/quickshell"
cache_file="$cache_dir/updates.cache"

mkdir -p "$cache_dir" || exit 0
tmp_file="$(mktemp "$cache_dir/updates.cache.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -f "$tmp_file"' EXIT

# Fetch updates safely (ensure exit 0 even if no updates or yay fails temporarily)
raw_updates="$(yay -Qu 2>/dev/null || true)"

if [[ -z "$raw_updates" ]]; then
    : > "$tmp_file"
else
    printf '%s\n' "$raw_updates" | xargs -r -d '\n' -n1 -P8 bash -c '
        read -r name old arrow new _ <<< "$1"
        source=$(yay -Si "$name" 2>/dev/null | awk '\''$1=="Repository" {repo=$3} $1=="Architecture" {architecture=$3} END {print repo, architecture}'\'')
        read -r repo architecture <<< "$source"
        printf "%s %s %s %s %s\n" "${repo:-unknown}" "${architecture:-x86_64}" "$name" "$old" "$new"
    ' updates-record | sort > "$tmp_file" || true
fi

cat "$tmp_file" > "$cache_file" 2>/dev/null || cp "$tmp_file" "$cache_file" 2>/dev/null || true
exit 0