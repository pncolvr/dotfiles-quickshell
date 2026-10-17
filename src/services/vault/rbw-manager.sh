#!/usr/bin/env bash
# One bounded JSON request/reply; secrets stay in stdin/stdout and process memory.
set +x
set -euo pipefail
ulimit -c 0
umask 077
export RUST_LOG=off
exec 2>/dev/null
fail() { printf '{"ok":false,"error":"%s"}\n' "$1"; exit 0; }
json() { printf '%s' "$request" | jq "$@"; }
rbw_read() {
    result=$(timeout --kill-after=2 90 rbw "$@" | head -c 5242881) || fail 'vault.worker.operation'
    (( ${#result} <= 5242880 )) || fail 'vault.worker.responseTooLarge'
}
IFS= read -r -n 1048577 request || fail 'vault.worker.invalidRequest'
(( ${#request} <= 1048576 )) || fail 'vault.worker.requestTooLarge'
json -e 'type == "object" and (.action | type == "string") and ([.. | strings | contains("\u0000")] | any | not)' >/dev/null || fail 'vault.worker.invalidRequest'
action=$(json -r '.action')
rbw_read --version
[[ $result == 'rbw 1.15.'* ]] || fail 'vault.worker.version'
# This is a versioned policy compatibility check, not an agent interface.
policy() {
    local config profile directory email server encoded path fd info matches
    rbw_read config show
    config=$result
    profile=${RBW_PROFILE:-}
    [[ $profile =~ ^[a-zA-Z0-9_-]*$ ]] || fail 'vault.worker.policy'
    directory=${XDG_CACHE_HOME:-$HOME/.cache}/rbw${profile:+-$profile}
    [[ -d $directory && -O $directory && ! -L $directory ]] || fail 'vault.worker.policy'
    info=$(stat -c %a -- "$directory")
    [[ $info == 700 ]] || fail 'vault.worker.policy'
    email=$(printf '%s' "$config" | jq -er '.email | select(type == "string" and length > 0 and (contains("/") or contains("\u0000") | not))') || fail 'vault.worker.policy'
    server=$(printf '%s' "$config" | jq -er '.base_url // "default" | select(type == "string" and (test("[\u0000-\u001f\u007f]") | not))') || fail 'vault.worker.policy'
    encoded=${server//%/%25}; encoded=${encoded//\//%2F}; encoded=${encoded//:/%3A}
    path=$directory/$encoded:$email.json
    [[ -f $path && -O $path && ! -L $path ]] || fail 'vault.worker.policy'
    exec {fd}< "$path"
    info=$(stat -Lc '%u:%s' "/proc/$$/fd/$fd")
    [[ ${info%%:*} == "$UID" && ${info#*:} -le 67108864 ]] || fail 'vault.worker.policy'
    matches=$(jq -ce --arg id "$id" '[.entries[] | select(.id == $id)] | select(length == 1 and .[0].master_password_reprompt == 0)' <&$fd) || fail 'vault.worker.protected'
    exec {fd}<&-
}
selected() {
    id=$(json -er '.id | select(type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))') || fail 'vault.worker.selection'
    policy
    rbw_read get --raw "$id"
    entry=$result
    printf '%s' "$entry" | jq -e --arg id "$id" '.id == $id and (.name | type == "string") and ((.data | type == "object") or .data == null) and ((.notes | type == "string") or .notes == null)' >/dev/null || fail 'vault.worker.invalidEntry'
    policy
    # Baseline includes fields not rendered by the UI; no plaintext baseline persists.
    baseline=$(printf '%s' "$entry" | jq -cS . | sha256sum); baseline=${baseline%% *}
}
notes_valid() {
    # rbw drops initial blank lines, trailing newlines, and all lines starting #.
    json -e '(.notes | type == "string" and length <= 262144 and (test("(^\n|\n$|\r|(^|\n)#)") | not)) and (.password // "" | type == "string" and length <= 16384 and (test("[\r\n]") | not))' >/dev/null || fail 'vault.worker.notesFormat'
}
case $action in
    list|sync)
        if [[ $action == sync ]]; then rbw_read sync; fi
        rbw_read list --raw
        printf '%s' "$result" | jq -ce 'select(type == "array" and length <= 20000) | map({id,name,user,folder,uris,type}) | select(all(.[]; (.id|type=="string") and (.name|type=="string"))) | {ok:true,entries:.}' || fail 'vault.worker.invalidList'
        ;;
    detail)
        selected
        # The private details view masks secrets, including TOTP configuration.
        # Password history remains omitted.
        printf '%s' "$entry" | jq -c --arg baseline "$baseline" '{ok:true,entry:{id,name,folder,notes,data,fields},baseline:$baseline}'
        ;;
    totp)
        selected
        printf '%s' "$entry" | jq -e '.data.totp | type == "string" and length > 0' >/dev/null || fail 'vault.worker.noTotp'
        rbw_read code "$id"
        [[ $result =~ ^[0-9]{1,10}$ || $result =~ ^[23456789BCDFGHJKMNPQRTVWXY]{5}$ ]] || fail 'vault.errors.totpResponse'
        token=$result
        policy
        printf '%s' "$token" | jq -Rs '{ok:true,token:.}'
        ;;
    add)
        json -e '.notes == ""' >/dev/null || fail 'vault.worker.readOnlyNotes'
        notes_valid
        json -e '(.name|type=="string" and length>0 and length<=1024) and (.username|type=="string" and length<=1024) and (.folder|type=="string" and length<=1024) and (.uris|type=="array" and length<=32 and all(.[]; type=="string" and length>0 and length<=4096 and (test("[\u0000-\u001f\u007f]")|not)))' >/dev/null || fail 'vault.worker.loginFields'
        name=$(json -r '.name'); username=$(json -r '.username'); folder=$(json -r '.folder')
        args=(add)
        [[ -z $folder ]] || args+=(--folder "$folder")
        while IFS= read -r uri; do args+=(--uri "$uri"); done < <(json -r '.uris[]')
        args+=(-- "$name")
        [[ -z $username ]] || args+=("$username")
        json -j '.password + "\n\n" + .notes' | timeout --kill-after=2 90 rbw "${args[@]}" >/dev/null || fail 'vault.worker.uncertainSave'
        printf '{"ok":true,"saved":true}\n'
        ;;
    edit|remove)
        rbw_read sync
        selected
        expected=$(json -er '.baseline | select(type=="string")') || fail 'vault.worker.reloadDetails'
        [[ $baseline == "$expected" ]] || fail 'vault.worker.changedEntry'
        if [[ $action == remove ]]; then
            rbw_read remove "$id"
        else
            kind=$(printf '%s' "$entry" | jq -r 'if .data == null then "note" elif (.data|has("password") and has("uris")) then "login" else "other" end')
            [[ $kind == login ]] || fail 'vault.worker.loginOnly'
            printf '%s\n%s\n' "$request" "$entry" | jq -es 'length == 2 and .[0].notes == (.[1].notes // "")' >/dev/null \
                || fail 'vault.worker.readOnlyNotes'
            notes_valid
            json -j '.password + "\n\n" + .notes' | timeout --kill-after=2 90 rbw edit "$id" >/dev/null || fail 'vault.worker.uncertainSave'
        fi
        printf '{"ok":true,"saved":true}\n'
        ;;
    generate)
        length=$(json -er '.length | select(type=="number" and floor==. and .>=8 and .<=128)') || fail 'vault.worker.passwordLength'
        rbw_read generate "$length"
        printf '%s' "$result" | jq -Rs '{ok:true,password:.}'
        ;;
    unlocked)
        if timeout 5 rbw unlocked >/dev/null; then printf '{"ok":true,"unlocked":true}\n'; else printf '{"ok":true,"unlocked":false}\n'; fi
        ;;
    lock) rbw_read lock; printf '{"ok":true,"locked":true}\n' ;;
    *) fail 'vault.worker.unsupported' ;;
esac
