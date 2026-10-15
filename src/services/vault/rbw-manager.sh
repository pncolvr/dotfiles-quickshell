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
    result=$(timeout --kill-after=2 90 rbw "$@" | head -c 5242881) || fail 'rbw operation failed or was cancelled. Refresh before retrying a write.'
    (( ${#result} <= 5242880 )) || fail 'rbw response exceeded the size limit.'
}
IFS= read -r -n 1048577 request || fail 'Invalid manager request.'
(( ${#request} <= 1048576 )) || fail 'Manager request exceeded the size limit.'
json -e 'type == "object" and (.action | type == "string") and ([.. | strings | contains("\u0000")] | any | not)' >/dev/null || fail 'Invalid manager request.'
action=$(json -r '.action')
rbw_read --version
[[ $result == 'rbw 1.15.'* ]] || fail 'Unsupported rbw version; this manager requires rbw 1.15.x.'
# This is a versioned policy compatibility check, not an agent interface.
policy() {
    local config profile directory email server encoded path fd info matches
    rbw_read config show
    config=$result
    profile=${RBW_PROFILE:-}
    [[ $profile =~ ^[a-zA-Z0-9_-]*$ ]] || fail 'Protected-entry policy could not be verified.'
    directory=${XDG_CACHE_HOME:-$HOME/.cache}/rbw${profile:+-$profile}
    [[ -d $directory && -O $directory && ! -L $directory ]] || fail 'Protected-entry policy could not be verified.'
    info=$(stat -c %a -- "$directory")
    [[ $info == 700 ]] || fail 'Protected-entry policy could not be verified.'
    email=$(printf '%s' "$config" | jq -er '.email | select(type == "string" and length > 0 and (contains("/") or contains("\u0000") | not))') || fail 'Protected-entry policy could not be verified.'
    server=$(printf '%s' "$config" | jq -er '.base_url // "default" | select(type == "string" and (test("[\u0000-\u001f\u007f]") | not))') || fail 'Protected-entry policy could not be verified.'
    encoded=${server//%/%25}; encoded=${encoded//\//%2F}; encoded=${encoded//:/%3A}
    path=$directory/$encoded:$email.json
    [[ -f $path && -O $path && ! -L $path ]] || fail 'Protected-entry policy could not be verified.'
    exec {fd}< "$path"
    info=$(stat -Lc '%u:%s' "/proc/$$/fd/$fd")
    [[ ${info%%:*} == "$UID" && ${info#*:} -le 67108864 ]] || fail 'Protected-entry policy could not be verified.'
    matches=$(jq -ce --arg id "$id" '[.entries[] | select(.id == $id)] | select(length == 1 and .[0].master_password_reprompt == 0)' <&$fd) || fail 'This entry is protected or its policy is unavailable. Use Bitwarden Desktop.'
    exec {fd}<&-
}
selected() {
    id=$(json -er '.id | select(type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))') || fail 'Select an entry first.'
    policy
    rbw_read get --raw "$id"
    entry=$result
    printf '%s' "$entry" | jq -e --arg id "$id" '.id == $id and (.name | type == "string") and ((.data | type == "object") or .data == null) and ((.notes | type == "string") or .notes == null)' >/dev/null || fail 'Invalid entry response.'
    policy
    # Baseline includes fields not rendered by the UI; no plaintext baseline persists.
    baseline=$(printf '%s' "$entry" | jq -cS . | sha256sum); baseline=${baseline%% *}
}
notes_valid() {
    # rbw drops initial blank lines, trailing newlines, and all lines starting #.
    json -e '(.notes | type == "string" and length <= 262144 and (test("(^\n|\n$|\r|(^|\n)#)") | not)) and (.password // "" | type == "string" and length <= 16384 and (test("[\r\n]") | not))' >/dev/null || fail 'rbw cannot preserve these notes or password: avoid leading/trailing blank lines, CR, and note lines beginning #.'
}
case $action in
    list|sync)
        if [[ $action == sync ]]; then rbw_read sync; fi
        rbw_read list --raw
        printf '%s' "$result" | jq -ce 'select(type == "array" and length <= 20000) | map({id,name,user,folder,uris,type}) | select(all(.[]; (.id|type=="string") and (.name|type=="string"))) | {ok:true,entries:.}' || fail 'Invalid vault list response.'
        ;;
    detail)
        selected
        # The private details view masks secrets, including TOTP configuration.
        # Password history remains omitted.
        printf '%s' "$entry" | jq -c --arg baseline "$baseline" '{ok:true,entry:{id,name,folder,notes,data,fields},baseline:$baseline}'
        ;;
    totp)
        selected
        printf '%s' "$entry" | jq -e '.data.totp | type == "string" and length > 0' >/dev/null || fail 'This entry has no TOTP secret.'
        rbw_read code "$id"
        [[ $result =~ ^[0-9]{1,10}$ || $result =~ ^[23456789BCDFGHJKMNPQRTVWXY]{5}$ ]] || fail 'Invalid TOTP token response.'
        token=$result
        policy
        printf '%s' "$token" | jq -Rs '{ok:true,token:.}'
        ;;
    add)
        json -e '.notes == ""' >/dev/null || fail 'Vault notes are read-only. Use Bitwarden Desktop to change them.'
        notes_valid
        json -e '(.name|type=="string" and length>0 and length<=1024) and (.username|type=="string" and length<=1024) and (.folder|type=="string" and length<=1024) and (.uris|type=="array" and length<=32 and all(.[]; type=="string" and length>0 and length<=4096 and (test("[\u0000-\u001f\u007f]")|not)))' >/dev/null || fail 'Enter a title and valid login fields.'
        name=$(json -r '.name'); username=$(json -r '.username'); folder=$(json -r '.folder')
        args=(add)
        [[ -z $folder ]] || args+=(--folder "$folder")
        while IFS= read -r uri; do args+=(--uri "$uri"); done < <(json -r '.uris[]')
        args+=(-- "$name")
        [[ -z $username ]] || args+=("$username")
        json -j '.password + "\n\n" + .notes' | timeout --kill-after=2 90 rbw "${args[@]}" >/dev/null || fail 'Save outcome is uncertain. Refresh and check before retrying.'
        printf '{"ok":true,"saved":true}\n'
        ;;
    edit|remove)
        rbw_read sync
        selected
        expected=$(json -er '.baseline | select(type=="string")') || fail 'Reload entry details before editing.'
        [[ $baseline == "$expected" ]] || fail 'Entry changed since it was opened. Discard the draft and reload details.'
        if [[ $action == remove ]]; then
            rbw_read remove "$id"
        else
            kind=$(printf '%s' "$entry" | jq -r 'if .data == null then "note" elif (.data|has("password") and has("uris")) then "login" else "other" end')
            [[ $kind == login ]] || fail 'Only login passwords can be edited. Use Bitwarden Desktop to edit notes and other item types.'
            printf '%s\n%s\n' "$request" "$entry" | jq -es 'length == 2 and .[0].notes == (.[1].notes // "")' >/dev/null \
                || fail 'Vault notes are read-only. Use Bitwarden Desktop to change them.'
            notes_valid
            json -j '.password + "\n\n" + .notes' | timeout --kill-after=2 90 rbw edit "$id" >/dev/null || fail 'Save outcome is uncertain. Refresh and check before retrying.'
        fi
        printf '{"ok":true,"saved":true}\n'
        ;;
    generate)
        length=$(json -er '.length | select(type=="number" and floor==. and .>=8 and .<=128)') || fail 'Choose a password length from 8 to 128.'
        rbw_read generate "$length"
        printf '%s' "$result" | jq -Rs '{ok:true,password:.}'
        ;;
    unlocked)
        if timeout 5 rbw unlocked >/dev/null; then printf '{"ok":true,"unlocked":true}\n'; else printf '{"ok":true,"unlocked":false}\n'; fi
        ;;
    lock) rbw_read lock; printf '{"ok":true,"locked":true}\n' ;;
    *) fail 'Unsupported manager operation.' ;;
esac
