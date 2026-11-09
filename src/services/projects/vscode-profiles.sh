# Shared helpers for code-profile.sh and integrations/vscode-profiles. Source, do not run.

# Parent directory holding one --user-data-dir per account profile.
vscode_profiles_root() {
    printf '%s\n' "${VSCODE_PROFILES_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/vscode-profiles}"
}

# Profile name -> directory name ("Work" -> "work", "Client A" -> "client-a").
vscode_profile_slug() {
    local slug=${1,,}
    slug=${slug//[^a-z0-9._-]/-}
    slug=$(sed -E 's/-+/-/g; s/^[-.]+//; s/-+$//' <<< "$slug")
    [[ -n $slug ]] || return 1
    printf '%s\n' "$slug"
}

# Prints the data dir for a profile name.
vscode_profile_dir() {
    local slug
    slug=$(vscode_profile_slug "$1") || return 1
    printf '%s/%s\n' "$(vscode_profiles_root)" "$slug"
}
