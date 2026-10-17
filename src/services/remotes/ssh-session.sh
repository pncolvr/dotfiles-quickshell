#!/usr/bin/env bash
# Interactive SSH and its jump/askpass callbacks share one implementation.
# Secrets are read locally from SQLite and returned only on askpass stdout.
set +x
set -euo pipefail
ulimit -c 0
unset BASH_ENV
read_entry() {
    [[ -f $database && -O $database && ! -L $database ]] || exit 2
    local key
    key=$(printf '%s' "$entry_id" | od -An -v -tx1 | tr -d ' \n')
    entry=$(sqlite3 -readonly -batch -cmd '.timeout 5000' "$database" \
        "SELECT payload_json FROM remotes WHERE id=CAST(X'$key' AS TEXT);" 2>/dev/null)
    jq -e '.type=="ssh"' <<< "$entry" >/dev/null
}

if [[ $# == 1 && -n ${QS_REMOTE_SSH_DATABASE:-} ]]; then
    if [[ ${SSH_ASKPASS_PROMPT:-} == none ]]; then
        printf '%s\n' "$1" > /dev/tty
        exit 0
    fi
    database=$QS_REMOTE_SSH_DATABASE entry_id=${QS_REMOTE_SSH_ID:?}
    read_entry
    prompt=$1
    kind=${prompt,,}
    kind=${kind%"${kind##*[![:space:]]}"}
    expected="${QS_REMOTE_SSH_USER:-}@${QS_REMOTE_SSH_HOST:-}'s password:"
    if [[ $PPID == "${QS_REMOTE_SSH_OWNER_PID:-}" && $kind == "${expected,,}" ]]; then
        field=password
        [[ ${QS_REMOTE_SSH_ROLE:-target} != jump ]] || field=hopPassword
        password=$(jq -r --arg field "$field" '.[$field] // ""' <<< "$entry")
        if [[ -n $password ]]; then printf '%s\n' "$password"; exit 0; fi
    fi
    # Askpass has stdout connected to SSH, so use the controlling terminal for
    # missing credentials, key passphrases and normal host-key confirmation.
    exec {terminal}<> /dev/tty
    printf '%s' "$prompt" >&"$terminal"
    if [[ ${SSH_ASKPASS_PROMPT:-} == confirm || $kind == *yes/no* ]]; then
        IFS= read -r answer <&"$terminal"
    else
        IFS= read -rs answer <&"$terminal"
        printf '\n' >&"$terminal"
    fi
    printf '%s\n' "$answer"
    exit 0
fi

mode=${1:?} database=${2:?} entry_id=${3:?} options=${4:?}
read_entry
mapfile -d '' -t ssh_command < <(jq -j '.ssh[] | ., "\u0000"' <<< "$options")
[[ ${#ssh_command[@]} -gt 0 ]] || exit 2
script=$(realpath -- "${BASH_SOURCE[0]}")
export SSH_ASKPASS=$script SSH_ASKPASS_REQUIRE=force
export QS_REMOTE_SSH_DATABASE=$database QS_REMOTE_SSH_ID=$entry_id
export QS_REMOTE_SSH_OWNER_PID=$$
# Do not borrow a user's multiplexed connection: this session must own its SSH.
args=(-o ControlMaster=no -o ControlPath=none -o ControlPersist=no -o ForkAfterAuthentication=no -o BatchMode=no)
case $mode in
    --connect)
        export QS_REMOTE_SSH_ROLE=target
        host=$(jq -r .endpoint <<< "$entry")
        port=$(jq -r .port <<< "$entry")
        user=$(jq -r '.username // ""' <<< "$entry")
        key_path=$(jq -r '.sshKeyPath // ""' <<< "$entry")
        hop=$(jq -r '.hopHost // ""' <<< "$entry")
        if [[ -n $hop ]]; then
            # ProxyCommand is the one SSH interface interpreted by a shell.
            # Quote every static argument and escape SSH's percent expansion.
            proxy=''
            for argument in bash "$script" --jump "$database" "$entry_id" "$options"; do
                escaped=${argument//\'/\'\\\'\'}
                proxy+="'$escaped' "
            done
            proxy=${proxy//%/%%}
            args+=(-o "ProxyCommand=$proxy'%h' '%p'")
        fi
        mapfile -d '' -t extra < <(jq -j '.sshArguments // [] | .[] | ., "\u0000"' <<< "$entry")
        args+=("${extra[@]}")
        ;;
    --jump)
        export QS_REMOTE_SSH_ROLE=jump
        host=$(jq -r .hopHost <<< "$entry")
        port=$(jq -r '.hopPort // 22' <<< "$entry")
        user=$(jq -r '.hopUsername // ""' <<< "$entry")
        key_path=$(jq -r '.hopKeyPath // ""' <<< "$entry")
        target=${5:?}
        target=${target#[}; target=${target%]}
        args+=(-W "[$target]:${6:?}")
        ;;
    *) exit 2 ;;
esac
host=${host#[}; host=${host%]}
[[ $key_path != "~/"* ]] || key_path="$HOME/${key_path:2}"
[[ -z $key_path ]] || args+=(-i "$key_path")
[[ -z $user ]] || args+=(-l "$user")
args+=(-p "$port" -- "$host")
# Resolve aliases/user defaults before matching password prompts. In particular,
# an implicit jump from SSH config must never receive the destination password.
identity=$("${ssh_command[@]}" -G "${args[@]}" 2>/dev/null)
unset QS_REMOTE_SSH_HOST QS_REMOTE_SSH_USER
while read -r key value; do
    case $key in
        hostname) export QS_REMOTE_SSH_HOST=$value ;;
        user) export QS_REMOTE_SSH_USER=$value ;;
    esac
done <<< "$identity"
# Release the shell's secret-bearing variables before replacing it with SSH.
unset entry password identity
exec "${ssh_command[@]}" "${args[@]}"
