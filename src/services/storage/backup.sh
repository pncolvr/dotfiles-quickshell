#!/usr/bin/env bash
# One JSON request on stdin; progress/results on stdout. Never log secrets.
set +x
set -Eeuo pipefail
ulimit -c 0
umask 077
export LC_ALL=C.UTF-8

temporary='' output_directory='' tokens_fd='' restore_armed=false previous_tokens=''
max_bytes=8589934592
json() { printf '%s' "$1" | jq "${@:2}"; }
emit() { jq -nc --arg type "$1" --arg message "${2:-}" --argjson args "${3:-[]}" '{type:$type,message:$message,args:$args}'; }
fail() { emit error "$1" "${2:-[]}"; exit 1; }
progress() { emit progress "$1"; }
owned_file() { [[ -f $1 && -O $1 && ! -L $1 ]]; }
owned_directory() { [[ -d $1 && -O $1 && ! -L $1 ]]; }
hash_file() { local hash rest; read -r hash rest < <(sha256sum < "$1"); printf '%s' "$hash"; }
# sqlite3 dot commands accept JSON's double-quoted string escaping.
dot_quote() { printf '%s' "$1" | jq -Rs .; }
snapshot() {
    printf '.timeout 10000\n.backup %s\n' "$(dot_quote "$2")" | sqlite3 -readonly "$1" >/dev/null 2>&1 || return 1
    chmod 600 -- "$2"
}

recover_storage() {
    local record=$directory/.restore-pending.json recovery_name recovery_path clipboard_path
    [[ -e $record ]] || return 0
    owned_file "$record" || return 1
    recovery_name=$(jq -er '.recovery | select(test("^backup-recovery\\.[A-Za-z0-9]{8}$"))' "$record") || return 1
    clipboard_path=$(jq -er '.clipboard | select(type == "string")' "$record") || return 1
    [[ $clipboard_path == "$directory/clipboard" ]] || return 1
    recovery_path=$directory/$recovery_name
    owned_directory "$recovery_path" && owned_file "$recovery_path/quickshell.db" \
        && owned_directory "$recovery_path/clipboard" || return 1
    snapshot "$recovery_path/quickshell.db" "$database" || return 1
    if [[ -e $clipboard_path ]]; then
        owned_directory "$clipboard_path" || return 1
        rm -rf -- "$clipboard_path" || return 1
    fi
    cp -a -- "$recovery_path/clipboard" "$clipboard_path" || return 1
    rm -- "$record"
}

keyring() {
    local action=$1 payload=${2:-'{}'} response
    response=$(printf '%s' "$payload" | jq -c --arg action "$action" '. + {action:$action}' |
        timeout --signal=TERM --kill-after=2s 600 env BASH_ENV='' "${totp_command[@]}" 2>/dev/null) || return 1
    json "$response" -e '.type == "backup" or .type == "restored"' >/dev/null || return 1
    printf '%s' "$response"
}
cleanup() {
    local status=$?
    trap - EXIT ERR INT TERM HUP
    set +e
    if $restore_armed; then
        local storage_ok=true tokens_ok=true
        recover_storage >/dev/null 2>&1 || storage_ok=false
        keyring backup-import "$previous_tokens" >/dev/null 2>&1 || tokens_ok=false
        if ! $storage_ok || ! $tokens_ok; then
            jq -nc --argjson required "$([[ $storage_ok == true ]] && printf false || printf true)" \
                '{type:"error",recoveryRequired:$required,message:"backup.worker.rollback"}'
        fi
    fi
    [[ -z $tokens_fd ]] || exec {tokens_fd}>&-
    [[ -z $temporary ]] || rm -rf -- "$temporary"
    [[ -z $output_directory ]] || rm -rf -- "$output_directory"
    unset password tokens previous_tokens request
    exit "$status"
}
trap cleanup EXIT
trap 'fail "backup.worker.operation"' ERR
trap 'exit 1' INT TERM HUP

if [[ ${1:-} == recover && $# == 2 ]]; then
    database=$(realpath -m -- "$2")
    directory=${database%/*}
    owned_directory "$directory" || exit 1
    exec {backup_lock}>"$directory/.backup.lock"
    flock -x -w 30 "$backup_lock"
    recover_storage
    exit 0
fi

IFS= read -r request
json "$request" -e 'type == "object" and (.action | type == "string")' >/dev/null
action=$(json "$request" -r .action)
if [[ $action == generate ]]; then
    # 192 random bits, rendered without punctuation that needs shell escaping.
    { printf '{"type":"generated","password":"'; head -c 24 /dev/urandom | base64 -w0; printf '"}\n'; }
    exit 0
fi
[[ $action == export || $action == import ]] || fail 'backup.worker.unknownOperation'
json "$request" -e '(.password | type == "string" and length > 0 and length <= 1024 and
    (explode | all(. >= 32 and . != 127))) and
    (.path | type == "string" and length > 0 and (explode | all(. >= 32 and . != 127))) and
    (.database | type == "string") and (.clipboard | type == "string") and
    (.schema | type == "number" and . >= 6 and . == floor) and
    (.totpCommand | type == "array" and length > 0 and all(.[]; type == "string"))' >/dev/null \
    || fail 'backup.worker.request'
password=$(json "$request" -r .password)
database=$(json "$request" -r .database)
database=$(realpath -m -- "$database")
directory=${database%/*}
clipboard=$(json "$request" -r .clipboard)
clipboard=$(realpath -m -- "$clipboard")
[[ $clipboard == "$directory/clipboard" ]] || fail 'backup.worker.clipboardLocation'
path=$(json "$request" -r .path)
[[ $path != '~/'* ]] || path=$HOME/${path:2}
path=$(realpath -ms -- "$path")
schema=$(json "$request" -r .schema)
mapfile -d '' -t totp_command < <(json "$request" -j '.totpCommand[] | ., "\u0000"')
unset request
sevenzip=$(command -v 7z || command -v 7zz) || fail 'backup.worker.sevenzip'
for dependency in sqlite3 jq sha256sum flock timeout; do
    command -v "$dependency" >/dev/null || fail 'backup.worker.dependency'
done
owned_directory "$directory" && owned_file "$database" || fail 'backup.worker.localData'
exec {backup_lock}>"$directory/.backup.lock"
flock -x -n "$backup_lock" || fail 'backup.worker.busy'
[[ ! -e $directory/.restore-pending.json ]] || fail 'backup.worker.pending'
temporary=$(mktemp -d "$directory/.backup.XXXXXXXX")

seven() {
    # A bare -p asks for a password only when creating. On reads, omit -p:
    # 7-Zip prompts on its pipe and consumes one line without exposing argv.
    printf '%s\n' "$password" | timeout --signal=TERM --kill-after=2s 900 \
        "$sevenzip" "$@" 2>/dev/null
}
inventory() {
    local source=$1
    version=$(sqlite3 -readonly "$source" 'PRAGMA user_version;' 2>/dev/null)
    [[ $version =~ ^[0-9]+$ ]] && ((version >= 6 && version <= schema)) \
        || fail 'backup.worker.version'
    [[ $(sqlite3 -readonly "$source" 'PRAGMA trusted_schema=OFF; PRAGMA integrity_check;' 2>/dev/null) == ok ]] \
        || fail 'backup.worker.integrity'
    sqlite3 -readonly -json "$source" 'SELECT id,mime,kind,bytes,pinned,updated_at FROM clipboard;' \
        > "$temporary/rows.json" 2>/dev/null
    # sqlite3 emits no JSON for an empty result.
    [[ -s $temporary/rows.json ]] || printf '[]' > "$temporary/rows.json"
    jq -e --argjson limit "$max_bytes" 'length <= 99996 and
        ([.[].id] | length == (unique | length)) and
        all(.[]; (.id | type == "string" and test("^[a-f0-9]{64}$")) and
            (.mime | type == "string" and test("^[A-Za-z0-9.+_-]+/[A-Za-z0-9.+_-]+(;[ -~]*)?$") and (contains("\\") | not)) and
            (.kind == "text" or .kind == "image") and
            (.bytes | type == "number" and . > 0 and . <= $limit and . == floor) and
            (.pinned == 0 or .pinned == 1) and (.updated_at | type == "number" and . == floor)) and
        ([.[].bytes] | add // 0) <= $limit' "$temporary/rows.json" >/dev/null \
        || fail 'backup.worker.metadata'
}
check_payloads() {
    local base=$1 mode=$2 id mime size file actual hash rest
    while IFS=$'\t' read -r id mime size; do
        file=$base/$id
        owned_file "$file" && [[ $(stat -c %s -- "$file") == "$size" ]] \
            || fail 'backup.worker.payloadMissing'
        read -r actual rest < <({ printf '%s\0' "$mime"; cat -- "$file"; } | sha256sum)
        [[ $actual == "$id" ]] || fail 'backup.worker.payloadIntegrity'
        if [[ $mode == export ]]; then
            cp -- "$file" "$temporary/stage/clipboard/$id"
            hash=$(hash_file "$temporary/stage/clipboard/$id")
            printf '%s clipboard/%s\n' "$hash" "$id" >> "$temporary/hashes"
        fi
    done < <(jq -r '.[] | [.id,.mime,.bytes] | @tsv' "$temporary/rows.json")
}
path_report() {
    local source=$1 table query
    # Historical schemas may predate Projects/Directories. Query only known
    # tables; this is a read-only availability check, never a discovery refresh.
    for table in project_sources projects project_workspaces directories; do
        [[ $(sqlite3 -readonly "$source" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table';") == 1 ]] || continue
        case $table in
            project_sources) query="SELECT path,'directory' AS kind,'source' AS type,path AS name FROM project_sources" ;;
            projects) query="SELECT path,'directory' AS kind,'project' AS type,MIN(name) AS name FROM projects GROUP BY path" ;;
            project_workspaces) query="SELECT path,'file' AS kind,'workspace' AS type,MIN(name) AS name FROM project_workspaces GROUP BY path" ;;
            directories) query="SELECT path,'directory' AS kind,'directory' AS type,name FROM directories" ;;
        esac
        sqlite3 -readonly -json "$source" "$query;" || return 1
    done > "$temporary/path-tables.json"
    jq -s 'add // []' "$temporary/path-tables.json" > "$temporary/paths.json"
    if ! timeout 10 bash "${BASH_SOURCE[0]%/*}/../files/resolve-folder.sh" --check \
        < "$temporary/paths.json" > "$temporary/checked-paths.json" 2>/dev/null; then
        jq 'map(. + {status:"unchecked",message:"files.path.unchecked"})' "$temporary/paths.json" > "$temporary/checked-paths.json"
    fi
    jq '{unavailable:map(select(.status == "unavailable")),unchecked:map(select(.status == "unchecked"))} |
        .counts = {directories:([.unavailable[]|select(.type == "directory")]|length),
            sources:([.unavailable[]|select(.type == "source")]|length),
            projects:([.unavailable[]|select(.type == "project")]|length),
            workspaces:([.unavailable[]|select(.type == "workspace")]|length)} |
        .warningCount = ((.unavailable|length) + (.unchecked|length)) |
        .summary = (if .warningCount == 0 then "Restored successfully" else
            "Restored successfully; " + (([.counts | to_entries[] | select(.value > 0) |
                "\(.value) \(if .value == 1 then (if .key == "directories" then "directory" else .key[0:-1] end) else .key end) unavailable"] +
                [if (.unchecked|length) > 0 then "\(.unchecked|length) \(if (.unchecked|length) == 1 then "location" else "locations" end) not checked" else empty end]) | join(", ")) end)' \
        "$temporary/checked-paths.json" > "$temporary/report.json"
}

if [[ $action == export ]]; then
    [[ $path == *.7z && ! -e $path && ! -L $path ]] || fail 'backup.worker.filename'
    [[ -d ${path%/*} ]] || fail backup.worker.folderMissing "$(jq -nc --arg path "${path%/*}" '[$path]')"
    owned_directory "${path%/*}" && [[ -w ${path%/*} ]] \
        || fail backup.worker.folderPermissions "$(jq -nc --arg path "${path%/*}" '[$path]')"
    progress 'backup.progress.readTotp'
    tokens=$(keyring backup-export) || fail 'backup.worker.totpRead'
    # An unlinked tmpfs file supplies a seekable descriptor to 7-Zip. Secrets
    # have no filename and are never staged on persistent storage.
    [[ $(stat -f -c %T /dev/shm) == tmpfs ]] || fail 'backup.worker.memory'
    memory_file=$(mktemp /dev/shm/quickshell-backup.XXXXXXXX)
    exec {tokens_fd}<>"$memory_file"
    rm -- "$memory_file"
    printf '%s' "$tokens" >&"$tokens_fd"
    mkdir -m700 -- "$temporary/stage" "$temporary/stage/clipboard"
    ln -s -- "/proc/$$/fd/$tokens_fd" "$temporary/stage/totp.json"
    progress 'backup.progress.database'
    snapshot "$database" "$temporary/stage/quickshell.db"
    inventory "$temporary/stage/quickshell.db"
    total_bytes=$(jq '[.[].bytes] | add // 0' "$temporary/rows.json")
    ((total_bytes + $(stat -c %s "$temporary/stage/quickshell.db") + ${#tokens} <= max_bytes)) \
        || fail 'backup.worker.archiveSize'
    printf '%s quickshell.db\n' "$(hash_file "$temporary/stage/quickshell.db")" > "$temporary/hashes"
    printf '%s totp.json\n' "$(hash_file "$temporary/stage/totp.json")" >> "$temporary/hashes"
    progress 'backup.progress.clipboard'
    check_payloads "$clipboard" export
    jq -Rn --arg created "$(date -u +%FT%TZ)" --argjson schema "$version" \
        '{format:"quickshell-backup",version:1,schema:$schema,createdAt:$created,
          files:(reduce inputs as $line ({}; ($line | split(" ")) as $parts | .[$parts[1]]=$parts[0]))}' \
        < "$temporary/hashes" > "$temporary/stage/manifest.json"
    output_directory=$(mktemp -d "${path%/*}/.quickshell-backup.XXXXXXXX")
    progress 'backup.progress.encrypt'
    (cd -- "$temporary/stage"; seven a -t7z -mhe=on -mx=3 -p "$output_directory/backup.7z" . >/dev/null) \
        || fail 'backup.worker.encrypt'
    chmod 600 -- "$output_directory/backup.7z"
    sync -f "$output_directory/backup.7z"
    ln -- "$output_directory/backup.7z" "$path" || fail 'backup.worker.destination'
    jq -nc --arg path "$path" '{type:"done",action:"export",path:$path}'
    exit 0
fi

owned_file "$path" && (($(stat -c %s -- "$path") <= max_bytes)) || fail 'backup.worker.archiveUnavailable'
progress 'backup.progress.validate'
cp -- "$path" "$temporary/archive.7z"
seven l -slt -ba "$temporary/archive.7z" > "$temporary/listing" \
    || fail 'backup.worker.openArchive'
# Parse properties without evaluating archive text. Reject duplicate properties,
# links, streams and every filename outside the fixed backup layout before x.
jq -Rse '
    sub("^\nEnter password:\n"; "") |
    split("\n\n") | map(split("\n") | map(select(length > 0))) |
    map(select(length > 0) | map(if test("^.+? = .*$") then capture("^(?<key>.+?) = (?<value>.*)$") else error("invalid") end) |
        if ([.[].key] | length != (unique | length)) then error("duplicate") else from_entries end) |
    select(length <= 100000) |
    select(all(.[];
        (keys | all(.[]; test("Link|Stream") | not)) and
        (if .Path == "clipboard" then (.Attributes | test("^D[A-Z_ ]* d[rwxstST-]{9}$"))
         else (.Path | test("^(manifest\\.json|quickshell\\.db|totp\\.json|clipboard/[a-f0-9]{64})$")) and
              .Encrypted == "+" and (.Attributes | test("^[A-Z_ ]* -[rwxstST-]{9}$")) and
              (.Size | test("^[0-9]+$")) end))) |
    select([.[].Path] | length == (unique | length)) |
    map(select(.Path != "clipboard") | {key:.Path,value:(.Size|tonumber)}) | from_entries |
    select(has("manifest.json") and has("quickshell.db") and has("totp.json")) |
    select(([.[]] | add) <= 8589934592 and .["manifest.json"] <= 16777216 and .["totp.json"] <= 67108864)
    ' "$temporary/listing" > "$temporary/members.json" 2>/dev/null \
    || fail 'backup.worker.archiveContents'
tokens=$(seven x -so "$temporary/archive.7z" totp.json) \
    || fail 'backup.worker.archiveTotp'
mkdir -m700 -- "$temporary/incoming"
seven x -y "-o$temporary/incoming" "$temporary/archive.7z" '-x!totp.json' >/dev/null \
    || fail 'backup.worker.extract'
mkdir -p -m700 -- "$temporary/incoming/clipboard"
[[ -z $(find "$temporary/incoming" -type l -print -quit) ]] || fail 'backup.worker.links'
find "$temporary/incoming" -type f -printf '%P\0' | jq -Rse --slurpfile members "$temporary/members.json" \
    '(split("\u0000") | map(select(length > 0)) | sort) == ($members[0] | del(.["totp.json"]) | keys)' >/dev/null \
    || fail 'backup.worker.manifestFiles'
find "$temporary/incoming" -type d -exec chmod 700 -- {} +
find "$temporary/incoming" -type f -exec chmod 600 -- {} +
manifest=$temporary/incoming/manifest.json
jq -e --slurpfile members "$temporary/members.json" '
    .format == "quickshell-backup" and .version == 1 and
    (.files | type == "object" and keys == ($members[0] | del(.["manifest.json"]) | keys)) and
    all(.files[]; type == "string" and test("^[a-f0-9]{64}$"))' "$manifest" >/dev/null \
    || fail 'backup.worker.manifest'
while IFS=$'\t' read -r member hash; do
    if [[ $member == totp.json ]]; then
        read -r actual rest < <(printf '%s' "$tokens" | sha256sum)
    else
        owned_file "$temporary/incoming/$member" || fail 'backup.worker.fileMissing'
        actual=$(hash_file "$temporary/incoming/$member")
    fi
    [[ $actual == "$hash" ]] || fail 'backup.worker.checksum'
done < <(jq -r '.files | to_entries[] | [.key,.value] | @tsv' "$manifest")
inventory "$temporary/incoming/quickshell.db"
[[ $(jq -r .schema "$manifest") == "$version" ]] || fail 'backup.worker.schema'
jq -e --slurpfile rows "$temporary/rows.json" \
    '[.files | keys[] | select(startswith("clipboard/"))] == ([$rows[0][] | "clipboard/" + .id] | sort)' \
    "$manifest" >/dev/null || fail 'backup.worker.clipboardMismatch'
check_payloads "$temporary/incoming/clipboard" import
json "$tokens" -e '.type == "backup" and .version == 1 and (.entries | type == "array")' >/dev/null \
    || fail 'backup.worker.totpFormat'
progress 'backup.progress.checkPaths'
path_report "$temporary/incoming/quickshell.db"
progress 'backup.progress.recovery'
previous_tokens=$(keyring backup-export) || fail 'backup.worker.currentTotp'
recovery=$(mktemp -d "$directory/backup-recovery.XXXXXXXX")
jq --arg recovery "$recovery" --arg archive "$path" --arg completedAt "$(date -u +%FT%TZ)" \
    '. + {recovery:$recovery,archive:$archive,completedAt:$completedAt,pendingNotice:true}' \
    "$temporary/report.json" > "$temporary/report-complete.json"
snapshot "$database" "$recovery/quickshell.db"
if [[ -e $clipboard ]]; then
    owned_directory "$clipboard" || fail 'backup.worker.clipboardUnsafe'
    cp -a -- "$clipboard" "$recovery/clipboard"
else
    mkdir -m700 -- "$recovery/clipboard"
fi
jq -nc --arg recovery "${recovery##*/}" --arg clipboard "$clipboard" '{recovery:$recovery,clipboard:$clipboard}' \
    > "$directory/.restore-pending.json"
sync -f "$directory"
restore_armed=true
progress 'backup.progress.restoreTotp'
keyring backup-import "$tokens" >/dev/null \
    || fail 'backup.worker.totpRestore'
progress 'backup.progress.restoreDatabase'
[[ ! -e $clipboard ]] || mv -- "$clipboard" "$temporary/old-clipboard"
mv -- "$temporary/incoming/clipboard" "$clipboard"
snapshot "$temporary/incoming/quickshell.db" "$database"
# Persist the import report in existing preferences so it survives reload. Hex
# encoding is SQL data, never executable path text or shell interpolation.
report_hex=$(od -An -v -tx1 "$temporary/report-complete.json" | tr -d ' \n')
printf "INSERT INTO preferences(key,value_json) VALUES('backup.lastRestore',CAST(X'%s' AS TEXT)) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json;\n" "$report_hex" \
    | sqlite3 "$database" >/dev/null 2>&1
sync -f "$directory"
rm -- "$directory/.restore-pending.json"
restore_armed=false
jq -nc --arg recovery "$recovery" --slurpfile report "$temporary/report-complete.json" \
    '{type:"done",action:"import",recovery:$recovery,report:$report[0]}'
