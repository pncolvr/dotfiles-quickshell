#!/usr/bin/env bash
# Seeds one isolated VS Code --user-data-dir per account profile from the existing
# profiles. Settings come along; sign-ins, secrets, cookies, Settings Sync and
# machine ids never do. The source data dir is only read.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helpers=$(cd -- "$here/../../src/services/projects" && pwd)
# shellcheck source=../../src/services/projects/vscode-profiles.sh
source "$helpers/vscode-profiles.sh"

usage() {
    cat <<'EOF'
Usage: bash integrations/vscode-profiles/seed.sh [OPTIONS] PROFILE[=[DIR:]SOURCE] ...

For each PROFILE, creates ROOT/<slug>/ (for example ROOT/work) as a separate VS Code
data dir with a profile named PROFILE, seeded from the SOURCE profile. SOURCE
defaults to the profile with the same name; "Default" means the default profile.
DIR picks the data dir SOURCE is read from, for this PROFILE only: a path
(containing "/" or starting with "~"), or the name of an account dir already
in ROOT, such as "work". Without DIR, --source is used.

Copied:     settings, keybindings, tasks, snippets, prompts, MCP and chat model
            config, extension list, the listed extensions (into the data dir's own
            extensions/ folder, hard-linked when possible), extension state with
            auth/session keys removed.
Not copied: secrets and sign-ins, cookies and web storage, Settings Sync, telemetry
            and machine ids, caches, logs, backups, local file history.

Options:
  --source DIR          source data dir (default: ~/.config/Code)
  --root DIR            parent of the new data dirs (default: $VSCODE_PROFILES_ROOT,
                        else ${XDG_DATA_HOME:-~/.local/share}/vscode-profiles)
  --workspaces PATH     also copy per-workspace UI state (open editors, layout) for
                        folders and .code-workspace files under PATH; repeatable
  --extension-storage   also copy extension globalStorage folders (auth-related
                        folders are skipped)
  --no-state            do not copy the extension state database
  --update              refresh config files of an existing data dir; its sign-ins,
                        state and extension list are left untouched. Also moves a
                        dir seeded before it had its own extensions/ folder over
  --dry-run             only print what would be done
  -h, --help            show this help

Examples:
  Assume Acme exists in ~/.config/Code; `seed.sh Acme` created ROOT/acme.

  Choose the source:
    seed.sh Acme
    seed.sh Contractor=Acme
    seed.sh Contractor=acme:Acme
    seed.sh Lab="$HOME/.config/Code - OSS":Default
    seed.sh --source "$HOME/.config/Code - OSS" Acme Lab=Default

  Also copy workspace UI state for folders under the given path:
    seed.sh --workspaces ~/Projects/green-one Contractor=Acme
    seed.sh --workspaces ~/Projects/green-one --workspaces ~/Projects/lab Lab

  Refresh an existing data dir:
    seed.sh --update Acme
    seed.sh --update Contractor=acme:Acme
EOF
}

die() { printf 'seed: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
run() {
    if ((dry_run)); then printf '  would run:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}

source_dir=$HOME/.config/Code
root=$(vscode_profiles_root)
workspace_prefixes=()
extension_storage=0
copy_state=1
update=0
dry_run=0
specs=()
while (($#)); do
    case $1 in
        --source) source_dir=${2:?--source needs a directory}; shift ;;
        --root) root=${2:?--root needs a directory}; shift ;;
        --workspaces) workspace_prefixes+=("$(realpath -m -- "${2:?--workspaces needs a path}")"); shift ;;
        --extension-storage) extension_storage=1 ;;
        --no-state) copy_state=0 ;;
        --update) update=1 ;;
        --dry-run) dry_run=1 ;;
        -h | --help) usage; exit 0 ;;
        --) shift; specs+=("$@"); break ;;
        -*) die "unknown option $1 (see --help)" ;;
        *) specs+=("$1") ;;
    esac
    shift
done
((${#specs[@]})) || { usage >&2; exit 2; }
for tool in jq sqlite3 realpath; do command -v "$tool" >/dev/null || die "$tool is required"; done
default_source=$(realpath -m -- "$source_dir")
root=$(realpath -m -- "$root")

# Removes anything that can identify or authenticate an account, then VACUUMs so
# deleted values do not linger in free pages.
sanitize_sql="
DELETE FROM ItemTable WHERE
    key LIKE 'secret://%' OR key LIKE '%authentication%' OR key LIKE '%authprovider%' OR key LIKE '%account%'
    OR key LIKE '%token%' OR key LIKE '%session%' OR key LIKE '%login%'
    OR key LIKE '%credential%' OR key LIKE '%oauth%' OR key LIKE '%password%'
    OR key LIKE 'sync.%' OR key LIKE '%settingssync%' OR key LIKE '%userdatasync%'
    OR key LIKE '%editsession%' OR key LIKE 'github.%' OR key LIKE 'vscode.github%'
    OR key LIKE 'ms-vscode.azure-account%' OR key LIKE '%telemetry%' OR key LIKE '%machineid%';
VACUUM;"
denied_storage='^(github\.|vscode\.github|ms-vscode\.azure-account|vscode-redhat-telemetry$)|auth|account|session|token|telemetry'

copy_sanitized_db() { # SOURCE_DB TARGET_DB
    local from=$1 to=$2 before after
    [[ -f $from ]] || return 0
    if ((dry_run)); then
        say "  would copy $from to $to without auth/sync/telemetry keys"
        return 0
    fi
    mkdir -p -- "$(dirname -- "$to")"
    rm -f -- "$to" "$to-wal" "$to-shm" "$to-journal"
    sqlite3 -readonly "$from" ".backup '${to//\'/\'\'}'"
    before=$(sqlite3 "$to" 'SELECT count(*) FROM ItemTable')
    sqlite3 "$to" "$sanitize_sql"
    after=$(sqlite3 "$to" 'SELECT count(*) FROM ItemTable')
    chmod 600 -- "$to"
    say "  state: kept $after of $before keys ($((before - after)) auth/sync/telemetry keys dropped)"
}

copy_config() { # FROM_DIR TO_DIR WITH_EXTENSION_LIST
    local from=$1 to=$2 file
    for file in settings.json keybindings.json tasks.json mcp.json chatLanguageModels.json; do
        [[ -f $from/$file ]] && run install -Dm600 -- "$from/$file" "$to/$file"
    done
    if (($3)) && [[ -f $from/extensions.json ]]; then run install -Dm600 -- "$from/extensions.json" "$to/extensions.json"; fi
    for file in snippets prompts; do
        [[ -d $from/$file ]] || continue
        run mkdir -p -- "$to/$file"
        run cp -a -- "$from/$file/." "$to/$file/"
    done
}

copy_tree() { # FROM TO: hard links when on one filesystem, else a full copy
    if ((dry_run)); then say "  would copy $1 to $2"; return 0; fi
    cp -al -- "$1" "$2" 2>/dev/null && return 0
    rm -rf -- "$2"
    cp -a -- "$1" "$2"
}

# Gives TARGET its own extensions folder. A shared one does not work: every VS Code
# instance deletes extensions that none of the profiles in its own data dir list,
# including ones another data dir still uses. Copies each listed extension that
# lives elsewhere and points the lists at the copies. Safe to rerun.
localize_extensions() { # TARGET
    local target=$1 dir=$1/extensions list path name id copied=0 missing
    run install -d -m700 -- "$dir"
    if [[ ! -f $dir/extensions.json ]]; then # default profile's list
        if ((dry_run)); then say "  would write $dir/extensions.json: []"
        else printf '[]\n' > "$dir/extensions.json"; chmod 600 -- "$dir/extensions.json"; fi
    fi
    for list in "$dir/extensions.json" "$target"/User/profiles/*/extensions.json; do
        [[ -f $list ]] || continue
        missing=()
        while IFS=$'\t' read -r path name id; do
            [[ -e $dir/$name ]] && continue
            if [[ ! -d $path ]]; then
                say "  $id is gone from $path; dropped from the list, reinstall it"
                missing+=("$name")
                continue
            fi
            copy_tree "$path" "$dir/$name"
            copied=$((copied + 1))
        done < <(jq -r --arg dir "$dir" '.[]? | select(.location.path? and (.location.path | startswith($dir + "/") | not))
            | [.location.path, (.relativeLocation // (.location.path | split("/") | last)), .identifier.id] | @tsv' "$list")
        if ((dry_run)); then continue; fi
        jq --arg dir "$dir" --args 'map(if .location.path? then
                .relativeLocation //= (.location.path | split("/") | last) | .location.path = $dir + "/" + .relativeLocation
            else . end | select(.relativeLocation as $name | $ARGS.positional | index([$name]) | not))' \
            "${missing[@]}" < "$list" > "$list.tmp"
        chmod 600 -- "$list.tmp"
        mv -- "$list.tmp" "$list"
    done
    say "  extensions: $copied copied into $dir"
}

url_to_path() { # file:// URI -> path, empty for anything else
    local uri=$1
    [[ $uri == file://* ]] || return 0
    uri=${uri#file://}
    printf '%b\n' "${uri//%/\\x}"
}

for spec in "${specs[@]}"; do
    name=${spec%%=*}
    from=$name
    [[ $spec == *=* ]] && from=${spec#*=}
    [[ -n $name && -n $from ]] || die "bad profile spec '$spec'"
    slug=$(vscode_profile_slug "$name") || die "profile name '$name' has no usable characters"
    target=$root/$slug

    # Optional DIR: prefix (split at the last ":"): a path, or an account dir in ROOT.
    source_dir=$default_source
    if [[ $from == *:* ]]; then
        dir=${from%:*}
        from=${from##*:}
        [[ -n $from ]] || from=$name
        [[ -n $dir ]] || die "bad profile spec '$spec' (empty DIR)"
        case $dir in
            "~" | "~/"*) source_dir=$HOME${dir#\~} ;;
            */*) source_dir=$dir ;;
            *) source_dir=$root/$(vscode_profile_slug "$dir") || die "bad DIR '$dir' in '$spec'" ;;
        esac
        source_dir=$(realpath -m -- "$source_dir")
    fi
    storage=$source_dir/User/globalStorage/storage.json
    [[ -f $storage ]] || die "no VS Code data dir at $source_dir"
    [[ $source_dir != "$target" ]] || die "$name would be seeded from itself ($target)"
    say "== $name -> $target (from $from in $source_dir)"

    if [[ -f $target/code.lock ]]; then
        pid=$(<"$target/code.lock")
        if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then die "VS Code is running on $target (pid $pid); close it first"; fi
    fi
    if [[ -e $target ]] && ((!update)); then die "$target exists; use --update to refresh its settings"; fi
    if [[ ! -e $target ]] && ((update)); then die "$target does not exist; seed it first without --update"; fi

    # Source profile: folder, extension list and "use default profile for X" flags.
    if [[ ${from,,} == default ]]; then
        source_profile=$source_dir/User
        source_extensions=$HOME/.vscode/extensions/extensions.json
        flags='{}'
        location=
    else
        entry=$(jq -ce --arg name "$from" '[.userDataProfiles[]? | select(.name == $name)][0] // empty' "$storage") \
            || die "no profile named '$from' in $source_dir (have: $(jq -r '[.userDataProfiles[]?.name] | join(", ")' "$storage"))"
        location=$(jq -r '.location' <<< "$entry")
        source_profile=$source_dir/User/profiles/$location
        source_extensions=$source_profile/extensions.json
        flags=$(jq -c '.useDefaultFlags // {}' <<< "$entry")
    fi
    [[ -d $source_profile ]] || die "missing profile folder $source_profile"

    # Target profile location: reuse the existing one when updating.
    target_storage=$target/User/globalStorage/storage.json
    if ((update)); then
        location=$(jq -r --arg name "$name" '[.userDataProfiles[]? | select(.name == $name)][0].location // empty' "$target_storage" 2>/dev/null) \
            || true
        [[ -n $location ]] || die "$target has no profile named '$name'"
    elif [[ -z $location ]]; then
        location=$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n')
    fi
    target_profile=$target/User/profiles/$location

    run install -d -m700 -- "$target" "$target/User" "$target/User/globalStorage" "$target_profile"
    if ((!update)); then
        say "  profile '$name' at profiles/$location (default-profile flags: $flags)"
        storage_json=$(jq -n --arg location "$location" --arg name "$name" --argjson flags "$flags" \
            '{userDataProfiles: [{location: $location, name: $name} + (if $flags == {} then {} else {useDefaultFlags: $flags} end)]}')
        if ((dry_run)); then say "  would write $target_storage: $storage_json"
        else printf '%s\n' "$storage_json" > "$target_storage"; chmod 600 -- "$target_storage"; fi
    fi

    # Default-profile files hold application-scoped settings and anything the
    # profile delegates through useDefaultFlags, so they are copied too.
    copy_config "$source_dir/User" "$target/User" 0
    if [[ $source_profile != "$source_dir/User" ]]; then copy_config "$source_profile" "$target_profile" 0; fi
    if ((!update)) && [[ -f $source_extensions ]]; then run install -Dm600 -- "$source_extensions" "$target_profile/extensions.json"; fi
    localize_extensions "$target"

    if ((!update && copy_state)); then
        copy_sanitized_db "$source_profile/globalStorage/state.vscdb" "$target_profile/globalStorage/state.vscdb"
    fi
    if ((!update && extension_storage)) && [[ -d $source_profile/globalStorage ]]; then
        for folder in "$source_profile/globalStorage"/*/; do
            [[ -d $folder ]] || continue
            folder=${folder%/}
            base=${folder##*/}
            if grep -Eqi -- "$denied_storage" <<< "$base"; then say "  skip extension storage $base"; continue; fi
            run cp -a -- "$folder" "$target_profile/globalStorage/$base"
        done
    fi

    # Per-workspace UI state, only for workspaces under the requested paths and
    # never over state the target already has.
    if ((${#workspace_prefixes[@]})); then
        copied=0
        for meta in "$source_dir/User/workspaceStorage"/*/workspace.json; do
            [[ -f $meta ]] || continue
            path=$(url_to_path "$(jq -r '.folder // .workspace // empty' "$meta")")
            [[ -n $path ]] || continue
            match=0
            for prefix in "${workspace_prefixes[@]}"; do
                [[ $path == "$prefix" || $path == "$prefix"/* ]] && match=1
            done
            ((match)) || continue
            hash=$(basename -- "$(dirname -- "$meta")")
            destination=$target/User/workspaceStorage/$hash
            [[ -e $destination ]] && continue
            run install -d -m700 -- "$destination"
            run install -m600 -- "$meta" "$destination/workspace.json"
            ((dry_run)) && say "  workspace $path" || copy_sanitized_db "$(dirname -- "$meta")/state.vscdb" "$destination/state.vscdb" >/dev/null
            copied=$((copied + 1))
        done
        say "  workspaces: $copied copied"
    fi
    say "  done. Launch: bash $helpers/code-profile.sh --profile $(printf '%q' "$name")"
done
