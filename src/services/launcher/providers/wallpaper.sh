#!/usr/bin/env bash
# Filesystem/awww boundary only. Native choices live in WallpaperService.
set -euo pipefail

provider_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$provider_dir/_common/utils.sh"

alert() {
    [[ $configured == false ]] || return 0
    "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "${QS_PICKER_CONFIG:-$provider_dir/../../../..}" \
        call alerts post wallpaper "$1" "$2" 3000 >/dev/null 2>&1 || true
}
fail() { printf '%s\n' "$1" >&2; alert "$1" error; exit 2; }

configured=false
if [[ ${1:-} == list ]]; then
    [[ $# == 2 && -d $2 ]] || { printf 'Wallpaper folder is unavailable\n' >&2; exit 2; }
    IFS= read -r -d '' folder < <(realpath -ez -- "$2") || exit 2
    printf '%s\0' "$folder"
    # Exec makes discovery cancellable as one owned process. Preserve literal paths.
    exec find -L "$folder" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.tif' -o -iname '*.tiff' \) -print0
fi
if [[ ${1:-} == --configured ]]; then
    configured=true
    shift
    [[ -n ${WALLPAPER_STATE_DIRECTORY:-} && ( ${WORK_MODE_ENABLED:-} == true || ${WORK_MODE_ENABLED:-} == false ) ]] \
        || fail "Could not read wallpaper configuration"
else
    load_provider_config || fail "Could not read wallpaper configuration"
fi
state_folder=$WALLPAPER_STATE_DIRECTORY

umask 077
work_dir=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/wallpaper.XXXXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

slot_for_output() {
    # Preserve the saved links used by the former Hyprland scripts.
    case $1 in DP-1) printf 1 ;; HDMI-A-1) printf 2 ;; *) printf '%s' "$1" ;; esac
}
validate_target() {
    [[ $1 =~ ^[a-zA-Z0-9_.:-]+$ ]] || fail "Invalid wallpaper output"
    [[ $2 == personal || $2 == work ]] || fail "Wallpaper mode must be personal or work"
}
monitors() {
    hyprctl monitors -j | jq -ce 'if type == "array" and length > 0
        and all(.[]; (.name | type == "string" and length > 0))
        then sort_by(.focused != true) else error("No connected monitors") end'
}
set_wallpaper() {
    local output=$1 mode=$2 path=$3 target
    # Numeric output arguments remain available to existing command-line callers.
    case $output in 1) output=DP-1 ;; 2) output=HDMI-A-1 ;; esac
    [[ $WORK_MODE_ENABLED == true ]] || mode=personal
    validate_target "$output" "$mode"
    [[ -f $path && -r $path ]] || fail "Wallpaper file is unavailable"
    IFS= read -r -d '' path < <(realpath -ez -- "$path") || fail "Wallpaper file is unavailable"
    local outputs
    outputs=$(monitors) || fail "Could not read connected monitors"
    jq -e --arg name "$output" 'any(.[]; .name == $name)' <<< "$outputs" >/dev/null \
        || fail "Wallpaper monitor is not connected: $output"
    mkdir -p -- "$state_folder" || fail "Could not access saved wallpaper folder"
    target="$state_folder/wallpaper_${mode}_$(slot_for_output "$output")"
    [[ ! -e $target || -L $target ]] || fail "Saved wallpaper path is not a symlink: $target"
    awww img "$path" --outputs "$output" --transition-type any --transition-duration 2 \
        || fail "Could not set wallpaper"
    ln -s -- "$path" "$work_dir/saved" || fail "Could not save wallpaper choice"
    mv -Tf -- "$work_dir/saved" "$target" || fail "Could not save wallpaper choice"
    alert "Wallpaper saved for $mode on $output" success
}
restore_wallpapers() {
    local mode=${1:-personal} outputs output target ready=false
    [[ $WORK_MODE_ENABLED == true ]] || mode=personal
    [[ $mode == personal || $mode == work ]] || fail "Wallpaper mode must be personal or work"
    outputs=$(monitors) || fail "Could not read connected monitors"
    # Hyprland starts awww-daemon separately; allow its socket to become ready.
    for ((attempt=0; attempt<30; attempt++)); do
        if awww query >/dev/null 2>&1; then ready=true; break; fi
        sleep 0.1
    done
    [[ $ready == true ]] || fail "Wallpaper daemon is unavailable"
    while IFS= read -r output; do
        validate_target "$output" "$mode"
        target="$state_folder/wallpaper_${mode}_$(slot_for_output "$output")"
        [[ -f $target ]] || continue
        awww img "$target" --outputs "$output" --transition-type any --transition-duration 0.5 \
            || fail "Could not restore wallpaper on $output"
    done < <(jq -r '.[].name' <<< "$outputs")
}
case ${1:-} in
    set) [[ $# == 4 ]] || fail "Usage: wallpaper set OUTPUT personal|work FILE"; set_wallpaper "$2" "$3" "$4" ;;
    restore) [[ $# -le 2 ]] || fail "Usage: wallpaper restore [personal|work]"; restore_wallpapers "${2:-personal}" ;;
    *) fail "Usage: wallpaper list DIRECTORY | set OUTPUT personal|work FILE | restore [personal|work]" ;;
esac
