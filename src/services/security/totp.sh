#!/usr/bin/env bash
# JSON requests on stdin, JSON replies on stdout. No secrets in argv or files.
set +x
set -uo pipefail
ulimit -c 0
export LC_ALL=C

vault=default
label='Quickshell TOTP'
secret_tool=secret-tool
oath_tool=oathtool
secret_timeout=30
default_period=30
default_digits=6
default_algorithm=SHA1
entries='[]'
loaded=false
ERROR=''
RESPONSE=''

fail() { ERROR=$1; return 1; }
json() { printf '%s' "$1" | jq "${@:2}"; }

check_dependencies() {
    command -v "$secret_tool" >/dev/null || { fail 'Install libsecret (secret-tool) to access the desktop keyring.'; return 1; }
    command -v "$oath_tool" >/dev/null || { fail 'Install oath-toolkit (oathtool) to generate TOTP codes.'; return 1; }
}

# Decode URI query values using Bash builtins, without evaluating user input.
urldecode() {
    local value=${1//+/ } prefix hex char result=''
    while [[ $value == *%* ]]; do
        prefix=${value%%\%*}
        value=${value#*%}
        hex=${value:0:2}
        [[ $hex =~ ^[[:xdigit:]]{2}$ && $hex != 00 ]] || { fail 'The TOTP URI has invalid encoding.'; return 1; }
        printf -v char '%b' "\\x$hex"
        result+=$prefix$char
        value=${value:2}
    done
    DECODED=$result$value
}

# Parsed token fields stay in shell memory. Store a canonical URI to retain defaults.
parse_token() {
    local value=$1 query part key decoded rem padded canonical
    local -a params=()
    local -A seen=()
    TOKEN_PERIOD=$default_period
    TOKEN_DIGITS=$default_digits
    TOKEN_ALGORITHM=$default_algorithm
    [[ -n $value && ${#value} -le 4096 ]] || { fail 'Enter a Base32 secret or an otpauth://totp URI.'; return 1; }
    if [[ $value == *://* ]]; then
        [[ $value == otpauth://totp/*\?* ]] || { fail 'Only standard otpauth://totp URIs are supported.'; return 1; }
        query=${value#*\?}
        query=${query%%#*}
        value=''
        IFS='&' read -r -a params < <(printf '%s\n' "$query")
        for part in "${params[@]}"; do
            urldecode "${part%%=*}" || return 1
            key=$DECODED
            [[ -n $key && ! ${seen[$key]+present} ]] || { fail 'The TOTP URI has duplicate or empty parameters.'; return 1; }
            seen[$key]=1
            urldecode "${part#*=}" || return 1
            decoded=$DECODED
            case $key in
                secret) value=$decoded ;;
                period) TOKEN_PERIOD=$decoded ;;
                digits) TOKEN_DIGITS=$decoded ;;
                algorithm) TOKEN_ALGORITHM=$decoded ;;
            esac
        done
    fi
    TOKEN_ALGORITHM=${TOKEN_ALGORITHM^^}
    [[ $TOKEN_ALGORITHM =~ ^(SHA1|SHA256|SHA512)$ ]] || { fail 'Use SHA1, SHA256, or SHA512.'; return 1; }
    [[ $TOKEN_PERIOD =~ ^[0-9]{1,5}$ && $TOKEN_DIGITS =~ ^[678]$ ]] || { fail 'Use 6–8 digits and a period of 1–86400 seconds.'; return 1; }
    TOKEN_PERIOD=$((10#$TOKEN_PERIOD))
    (( TOKEN_PERIOD >= 1 && TOKEN_PERIOD <= 86400 )) || { fail 'Use a period of 1–86400 seconds.'; return 1; }
    TOKEN_SECRET=$(printf '%s' "$value" | tr -d '[:space:]-')
    TOKEN_SECRET=${TOKEN_SECRET^^}
    while [[ $TOKEN_SECRET == *= ]]; do TOKEN_SECRET=${TOKEN_SECRET%=}; done
    [[ $TOKEN_SECRET =~ ^[A-Z2-7]+$ ]] || { fail 'The secret must be Base32 (A–Z and 2–7).'; return 1; }
    rem=$((${#TOKEN_SECRET} % 8))
    [[ $rem =~ ^[02457]$ ]] || { fail 'The Base32 secret is incomplete.'; return 1; }
    padded=$TOKEN_SECRET
    while (( ${#padded} % 8 )); do padded+='='; done
    canonical=$(printf '%s' "$padded" | base32 --decode 2>/dev/null | base32 --wrap=0) || { fail 'The Base32 secret is invalid.'; return 1; }
    while [[ $canonical == *= ]]; do canonical=${canonical%=}; done
    [[ $canonical == "$TOKEN_SECRET" ]] || { fail 'The Base32 secret is invalid.'; return 1; }
    TOKEN_URI="otpauth://totp/Quickshell?secret=$TOKEN_SECRET&algorithm=$TOKEN_ALGORITHM&digits=$TOKEN_DIGITS&period=$TOKEN_PERIOD"
    (( ${#TOKEN_URI} <= 4096 )) || { fail 'The TOTP secret or URI is too long.'; return 1; }
}

generate_code() {
    local timestamp=$1
    CODE=$(printf '%s\n' "$TOKEN_SECRET" | timeout --signal=KILL "$secret_timeout" "$oath_tool" \
        --totp="$TOKEN_ALGORITHM" --base32 --digits="$TOKEN_DIGITS" \
        --time-step-size="${TOKEN_PERIOD}s" --now="@$timestamp" - 2>/dev/null) || { fail 'TOTP generation failed. Check oathtool and the token.'; return 1; }
    [[ $CODE =~ ^[0-9]+$ && ${#CODE} -eq TOKEN_DIGITS ]] || { fail 'Invalid response from oathtool.'; return 1; }
}

load_vault() {
    local raw line payload item next='[]' blocks=0 secrets=0 token
    check_dependencies || return 1
    raw=$(timeout --signal=KILL "$secret_timeout" "$secret_tool" search --all --unlock "${attributes[@]}" 2>/dev/null) || { fail 'Cannot read the desktop keyring. Start or unlock your Secret Service and reload.'; return 1; }
    while IFS= read -r line; do
        if [[ $line =~ ^\[[^]]+\]$ ]]; then ((blocks+=1)); fi
        [[ $line == 'secret = '* ]] || continue
        ((secrets+=1))
        payload=${line#secret = }
        item=$(json "$payload" -ce '
            select(.version == 1 and (.id | type == "string" and test("^[a-f0-9-]{36}$"))
                and (.name | type == "string" and length > 0 and length <= 128 and (explode | all(. >= 32 and . != 127)))
                and (.token | type == "string")) | {id, name, token}') || { fail 'A TOTP entry in the keyring is invalid. Repair it before saving.'; return 1; }
        token=$(json "$item" -r .token)
        parse_token "$token" || { fail 'A TOTP entry in the keyring has an invalid token.'; return 1; }
        next=$(printf '%s\n%s\n' "$next" "$item" | jq -cs '.[0] + [.[1]]') || return 1
    done < <(printf '%s\n' "$raw")
    (( blocks == secrets )) || { fail 'The TOTP keyring is locked. Unlock it and reload.'; return 1; }
    json "$next" -e '[.[].id] | length == (unique | length)' >/dev/null || { fail 'Duplicate TOTP entries were found. Repair them in the keyring.'; return 1; }
    entries=$(json "$next" -c 'sort_by(.name | ascii_downcase)')
}

snapshot() {
    local action=$1 id=$2 timestamp entry token expires rows='' row next_expiry next_period
    timestamp=$(date +%s)
    next_expiry=$(((timestamp / default_period + 1) * default_period))
    next_period=$default_period
    local first=true
    while IFS= read -r entry; do
        [[ -n $entry ]] || continue
        token=$(json "$entry" -r .token)
        parse_token "$token" || return 1
        generate_code "$timestamp" || return 1
        expires=$(((timestamp / TOKEN_PERIOD + 1) * TOKEN_PERIOD))
        if $first || (( expires < next_expiry )); then
            next_expiry=$expires
            next_period=$TOKEN_PERIOD
            first=false
        fi
        row=$(printf '%s\n"%s"\n' "$entry" "$CODE" | jq -cs --argjson expires "$expires" \
            '.[1] as $code | .[0] | {id, name, code: $code, expiresAt: $expires}') || return 1
        rows+=$row$'\n'
    done < <(json "$entries" -c '.[]')
    RESPONSE=$(printf '%s' "$rows" | jq -cs --arg action "$action" --arg id "$id" \
        --argjson timestamp "$timestamp" --argjson expires "$next_expiry" --argjson period "$next_period" \
        '{type: "snapshot", action: $action, id: $id, entries: ., timestamp: $timestamp, expiresAt: $expires, period: $period}')
}

handle() {
    local request=$1 action id entry name token replacement payload size
    action=$(json "$request" -r '.action // ""')
    id=$(json "$request" -r '.id // ""')
    case $action in
        load)
            loaded=false
            load_vault || return 1
            loaded=true
            snapshot load ''
            return $? ;;
        refresh)
            $loaded || { fail 'Load the keyring first.'; return 1; }
            snapshot refresh ''
            return $? ;;
        save|delete|edit|copy) ;;
        *) fail 'Unknown TOTP operation.'; return 1 ;;
    esac
    $loaded || { fail 'Load the keyring before changing entries.'; return 1; }
    [[ -z $id || $id =~ ^[a-f0-9-]{36}$ ]] || { fail 'Invalid entry identifier.'; return 1; }
    # Read before changes to preserve sequential edits made by other keyring clients.
    if [[ $action != copy ]]; then load_vault || return 1; fi
    entry=$(json "$entries" -c --arg id "$id" '.[] | select(.id == $id)')
    if [[ -n $id || $action != save ]]; then
        [[ -n $entry ]] || { fail 'This entry no longer exists. Reload the keyring.'; return 1; }
    fi
    case $action in
        edit)
            RESPONSE=$(json "$entry" -c '{type: "edit", id, name, token}')
            return $? ;;
        copy)
            token=$(json "$entry" -r .token)
            parse_token "$token" || return 1
            generate_code "$(date +%s)" || return 1
            RESPONSE=$(printf '"%s"' "$CODE" | jq -c --arg id "$id" '{type: "copy", id: $id, code: .}')
            return $? ;;
        save)
            name=$(json "$request" -er '.name | select(type == "string") | gsub("^\\s+|\\s+$"; "") | select(length > 0 and length <= 128 and (explode | all(. >= 32 and . != 127)))') || { fail 'Enter a name of 1–128 characters without control characters.'; return 1; }
            token=$(json "$request" -er '.token | select(type == "string") | gsub("^\\s+|\\s+$"; "")') || { fail 'Enter a Base32 secret or an otpauth URI.'; return 1; }
            parse_token "$token" || return 1
            if [[ -z $id ]]; then IFS= read -r id < /proc/sys/kernel/random/uuid; fi
            replacement=$(printf '%s\n' "$name" "$TOKEN_URI" | jq -Rsc --arg id "$id" \
                'split("\n") | {id: $id, name: .[0], token: .[1]}') || return 1
            payload=$(json "$replacement" -c '. + {version: 1}')
            size=$(printf '%s' "$payload" | wc -c)
            (( size < 8192 )) || { fail 'This token is too large for secret-tool.'; return 1; }
            printf '%s' "$payload" | timeout --signal=KILL "$secret_timeout" "$secret_tool" store \
                "--label=$label" "${attributes[@]}" id "$id" >/dev/null 2>&1 || { fail 'Cannot save the token. Unlock the keyring and retry.'; return 1; }
            entries=$(printf '%s\n%s\n' "$entries" "$replacement" | jq -cs \
                '.[1] as $new | [.[0][] | select(.id != $new.id)] + [$new] | sort_by(.name | ascii_downcase)') ;;
        delete)
            timeout --signal=KILL "$secret_timeout" "$secret_tool" clear "${attributes[@]}" id "$id" >/dev/null 2>&1 || { fail 'Cannot delete the token. Unlock the keyring and retry.'; return 1; }
            entries=$(json "$entries" -c --arg id "$id" 'map(select(.id != $id))') ;;
    esac
    snapshot "$action" "$id"
}

main() {
    local request action
    while (( $# >= 2 )); do
        case $1 in
            --vault) vault=$2 ;; --label) label=$2 ;;
            --secret-tool) secret_tool=$2 ;; --oath-tool) oath_tool=$2 ;;
            --timeout) secret_timeout=$2 ;; --period) default_period=$2 ;;
            --digits) default_digits=$2 ;; --algorithm) default_algorithm=$2 ;;
            *) return 1 ;;
        esac
        shift 2
    done
    command -v jq >/dev/null || return 1
    local -a attributes=(application quickshell type totp vault "$vault")
    [[ $secret_timeout =~ ^[1-9][0-9]*$ && $default_period =~ ^[1-9][0-9]{0,4}$ ]] || return 1
    while IFS= read -r request; do
        ERROR=''
        RESPONSE=''
        if ! json "$request" -e 'type == "object" and (.action | type == "string")' >/dev/null 2>&1; then
            printf '%s\n' '{"type":"error","message":"Invalid TOTP request."}'
            continue
        fi
        action=$(json "$request" -r .action)
        [[ $action == quit ]] && return 0
        if handle "$request" 2>/dev/null; then printf '%s\n' "$RESPONSE"
        else
            printf '%s' "${ERROR:-The TOTP operation failed. Reload and retry.}" | jq -Rc --arg action "$action" \
                '{type: "error", action: $action, message: .}'
        fi
    done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
