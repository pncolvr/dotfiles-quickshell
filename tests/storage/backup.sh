#!/usr/bin/env bash
# Synthetic clipboard and public RFC seeds only; never opens the desktop keyring.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d "/tmp/quickshell-backup test.'XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/data" "$fixture/data/clipboard" "$fixture/keyring" "$fixture/bin"
export BACKUP_TEST_STORE=$fixture/keyring BACKUP_TEST_STATE=$fixture
actual_sevenzip=$(command -v 7z || command -v 7zz)
export BACKUP_TEST_7Z=$actual_sevenzip
cat > "$fixture/bin/secret-tool" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
    search)
        [[ ! -f $BACKUP_TEST_STORE/locked ]] || exit 1
        for item in "$BACKUP_TEST_STORE"/*.json; do
            [[ -f $item ]] || continue
            printf '[item]\nsecret = '; cat -- "$item"; printf '\n'
        done ;;
    store)
        if [[ -f $BACKUP_TEST_STORE/fail-once ]]; then rm -- "$BACKUP_TEST_STORE/fail-once"; exit 1; fi
        cat > "$BACKUP_TEST_STORE/${!#}.json" ;;
    clear) rm -f -- "$BACKUP_TEST_STORE/${!#}.json" ;;
    *) exit 1 ;;
esac
MOCK
cat > "$fixture/bin/7z" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$BACKUP_TEST_STATE/7z-arguments"
exec "$BACKUP_TEST_7Z" "$@"
MOCK
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
database=$fixture/data/quickshell.db
sqlite3 "$database" <<'SQL'
PRAGMA user_version=12;
CREATE TABLE clipboard(id TEXT PRIMARY KEY,mime TEXT,kind TEXT,bytes INTEGER,text TEXT,updated_at INTEGER,pinned INTEGER);
CREATE TABLE preferences(key TEXT PRIMARY KEY,value_json TEXT);
INSERT INTO preferences VALUES('clock.showSeconds','true');
CREATE TABLE twitch_users(login TEXT PRIMARY KEY,fallback_login TEXT);
INSERT INTO twitch_users VALUES('fixture','second');
CREATE TABLE project_sources(path TEXT PRIMARY KEY,kind TEXT,category TEXT);
CREATE TABLE projects(source_path TEXT,path TEXT,name TEXT,remote_url TEXT);
CREATE TABLE project_workspaces(project_path TEXT,path TEXT,name TEXT,included INTEGER);
CREATE TABLE directories(path TEXT PRIMARY KEY,name TEXT,category TEXT);
CREATE TABLE webapps(id TEXT PRIMARY KEY,name TEXT,payload_json TEXT);
INSERT INTO webapps VALUES('webapp-test','Fixture','{"url":"https://example.test/app","browser":"vivaldi","profile":"Test Profile","arguments":["literal $(no-execution)"]}');
SQL
mkdir "$fixture/source" "$fixture/project-present" "$fixture/project-missing" "$fixture/directory-present" "$fixture/directory-missing"
printf '{}' > "$fixture/project-present/test.code-workspace"
jq -nc --arg root "$fixture" '[
    {path:($root+"/source"),kind:"directory"},
    {path:($root+"/project-present/test.code-workspace"),kind:"file"},
    {path:"smb://server/share",kind:"directory"}]' | bash "$repo/src/services/files/resolve-folder.sh" --check \
    | jq -e '.[0].status == "available" and .[1].status == "available" and .[2].status == "unchecked"' >/dev/null
# Bind fixture paths as SQL data without shell/SQL quoting assumptions.
fixture_hex=$(printf '%s' "$fixture" | od -An -v -tx1 | tr -d ' \n')
sqlite3 "$database" <<SQL
INSERT INTO project_sources VALUES(CAST(X'$fixture_hex' AS TEXT)||'/source','root','personal');
INSERT INTO projects VALUES(CAST(X'$fixture_hex' AS TEXT)||'/source',CAST(X'$fixture_hex' AS TEXT)||'/project-present','Present','');
INSERT INTO projects VALUES(CAST(X'$fixture_hex' AS TEXT)||'/source',CAST(X'$fixture_hex' AS TEXT)||'/project-missing','Missing','');
INSERT INTO project_workspaces VALUES(CAST(X'$fixture_hex' AS TEXT)||'/project-present',CAST(X'$fixture_hex' AS TEXT)||'/project-present/test.code-workspace','Workspace',1);
INSERT INTO directories VALUES(CAST(X'$fixture_hex' AS TEXT)||'/directory-present','Present','personal');
INSERT INTO directories VALUES(CAST(X'$fixture_hex' AS TEXT)||'/directory-missing','Missing','personal');
INSERT INTO directories VALUES('smb://server/share','Remote','work');
SQL
text_id=$({ printf 'text/plain\0'; printf 'Public clipboard fixture'; } | sha256sum); text_id=${text_id%% *}
printf 'Public clipboard fixture' > "$fixture/data/clipboard/$text_id"
image_id=$({ printf 'image/png\0'; cat "$repo/src/assets/twitch.png"; } | sha256sum); image_id=${image_id%% *}
cp "$repo/src/assets/twitch.png" "$fixture/data/clipboard/$image_id"
sqlite3 "$database" "INSERT INTO clipboard VALUES('$text_id','text/plain','text',24,'Public clipboard fixture',101,1);
INSERT INTO clipboard VALUES('$image_id','image/png','image',$(stat -c %s "$repo/src/assets/twitch.png"),'',102,0);"
cat > "$fixture/keyring/11111111-1111-1111-1111-111111111111.json" <<'JSON'
{"version":1,"id":"11111111-1111-1111-1111-111111111111","name":"RFC fixture","token":"otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&algorithm=SHA256&digits=8&period=60"}
JSON
totp_command=$(jq -nc --arg helper "$repo/src/services/security/totp.sh" --arg tool "$fixture/bin/secret-tool" \
    '["bash",$helper,"--secret-tool",$tool]')
request() {
    jq -nc --arg action "$1" --arg path "$2" --arg password "${3:-Public-fixture-passphrase}" \
        --arg database "$database" --arg clipboard "$fixture/data/clipboard" --argjson totp "$totp_command" \
        '{action:$action,path:$path,password:$password,database:$database,clipboard:$clipboard,schema:12,totpCommand:$totp}'
}
run() { request "$@" | bash "$repo/src/services/storage/backup.sh"; }
reject() {
    if run "$@" > "$fixture/rejected.log"; then printf 'FAIL: accepted %s\n' "$1"; exit 1; fi
    jq -se 'any(.[]; .type == "error")' "$fixture/rejected.log" >/dev/null
}
runtime_database=$fixture/data/recording-runtime.db
sqlite3 "$runtime_database" "CREATE TABLE recording_session(id INTEGER PRIMARY KEY,payload TEXT); INSERT INTO recording_session VALUES(1,'synthetic worker identity');"
runtime_hash=$(sha256sum "$runtime_database")
archive=$fixture/backup.7z
run export "$archive" > "$fixture/export.log"
jq -se '.[-1].type == "done"' "$fixture/export.log" >/dev/null
[[ $(stat -c %a "$archive") == 600 ]]
if printf 'wrong\n' | "$actual_sevenzip" l -slt "$archive" > "$fixture/wrong-list.log" 2>&1; then exit 1; fi
! rg -q 'quickshell.db|totp.json|clipboard/' "$fixture/wrong-list.log"
! rg -q 'Public-fixture-passphrase|JBSWY3DPEHPK3PXP' "$fixture/7z-arguments"
printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" x -so "$archive" totp.json \
    | jq -e '.entries[0] | .name == "RFC fixture" and (.token | contains("algorithm=SHA256&digits=8&period=60"))' >/dev/null
printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" l -slt "$archive" > "$fixture/archive-list"
! rg -q 'recording-runtime\.db' "$fixture/archive-list"
reject export "$archive"
printf 'PASS: encrypted archive/header, complete TOTP parameters, stdin-only password and overwrite refusal\n'
run export "$fixture/unicode.7z" 'Public fixture é ! $() `literal`' > "$fixture/unicode.log"
printf '%s\n' 'Public fixture é ! $() `literal`' | "$actual_sevenzip" x -so "$fixture/unicode.7z" totp.json \
    | jq -e '.entries | length == 1' >/dev/null
printf 'PASS: spaces/quotes in paths and Unicode/literal shell characters in passwords\n'
rm -r -- "$fixture/source" "$fixture/project-missing" "$fixture/directory-missing"
rm -- "$fixture/project-present/test.code-workspace"

sqlite3 "$database" "UPDATE preferences SET value_json='false'; DELETE FROM clipboard; DELETE FROM twitch_users; DELETE FROM webapps;"
rm -- "$fixture/data/clipboard/$text_id" "$fixture/data/clipboard/$image_id"
printf '%s' '{"version":1,"id":"22222222-2222-2222-2222-222222222222","name":"New","token":"MY"}' \
    > "$fixture/keyring/22222222-2222-2222-2222-222222222222.json"
database_inode=$(stat -c %i "$database")
reject import "$archive" wrong
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM clipboard;') == 0 ]]
[[ ! -e $fixture/data/.restore-pending.json ]]
run import "$archive" > "$fixture/import.log"
jq -se '.[-1].type == "done" and (.[-1].recovery | length > 0)' "$fixture/import.log" >/dev/null
[[ $(stat -c %i "$database") == "$database_inode" ]]
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM clipboard;') == 2 ]]
[[ $(sqlite3 "$database" "SELECT pinned||':'||updated_at FROM clipboard WHERE id='$text_id';") == 1:101 ]]
[[ $(sqlite3 "$database" 'SELECT fallback_login FROM twitch_users;') == second ]]
sqlite3 "$database" 'SELECT payload_json FROM webapps;' | jq -e '.profile=="Test Profile" and .arguments==["literal $(no-execution)"]' >/dev/null
printf 'PASS: webapp launch data survive encrypted restore\n'
[[ $(sqlite3 "$database" "SELECT value_json FROM preferences WHERE key='clock.showSeconds';") == true ]]
jq -se '.[-1].report | .warningCount == 5 and .counts == {directories:1,sources:1,projects:1,workspaces:1} and
    (.unchecked | length == 1 and .[0].path == "smb://server/share") and .pendingNotice' "$fixture/import.log" >/dev/null
sqlite3 "$database" "SELECT value_json FROM preferences WHERE key='backup.lastRestore';" \
    | jq -e '.warningCount == 5 and (.unavailable | length == 4)' >/dev/null
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM projects; SELECT COUNT(*) FROM directories;') == $'2\n3' ]]
printf 'PASS: missing saved paths retained; import reports folders/workspaces and unchecked remote URIs persistently\n'
[[ -f $fixture/data/clipboard/$text_id && -f $fixture/data/clipboard/$image_id ]]
[[ ! -e $fixture/keyring/22222222-2222-2222-2222-222222222222.json ]]
[[ $(stat -c %a "$database") == 600 && $(stat -c %a "$fixture/data/clipboard") == 700 ]]
[[ $(sha256sum "$runtime_database") == "$runtime_hash" ]]
printf 'PASS: runtime recording state is excluded from backup and preserved during restore\n'
printf 'PASS: full restore, pins/recency/payloads/Twitch/preferences/keyring and database inode preservation\n'

touch "$fixture/keyring/fail-once"
reject import "$archive"
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM clipboard;') == 2 ]]
[[ -f $fixture/keyring/11111111-1111-1111-1111-111111111111.json ]]
[[ ! -e $fixture/data/.restore-pending.json ]]
touch "$fixture/keyring/locked"
reject export "$fixture/locked.7z"
[[ ! -e $fixture/locked.7z ]]
rm "$fixture/keyring/locked"
printf 'PASS: locked keyring and failed keyring write preserve prior storage and tokens\n'

# Repack public fixtures to exercise structural and integrity validation.
mkdir -m700 "$fixture/repacked"
printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" x -y "-o$fixture/repacked" "$archive" >/dev/null
printf damaged > "$fixture/repacked/clipboard/$text_id"
(cd "$fixture/repacked"; printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" a -t7z -mhe=on -p "$fixture/damaged.7z" . >/dev/null)
reject import "$fixture/damaged.7z"
printf unexpected > "$fixture/repacked/unexpected.txt"
(cd "$fixture/repacked"; printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" a -t7z -mhe=on -p "$fixture/unexpected.7z" . >/dev/null)
reject import "$fixture/unexpected.7z"
rm -- "$fixture/repacked/unexpected.txt" "$fixture/repacked/clipboard/$text_id"
ln -s -- "$fixture/never-follow-this" "$fixture/repacked/clipboard/$text_id"
(cd "$fixture/repacked"; printf 'Public-fixture-passphrase\n' | "$actual_sevenzip" a -snl -t7z -mhe=on -p "$fixture/linked.7z" . >/dev/null)
reject import "$fixture/linked.7z"
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM clipboard;') == 2 ]]
printf 'PASS: damaged payloads, links and unexpected archive paths rejected before changes\n'

# Recreate the startup journal left by an abrupt interruption.
recovery=$(jq -sr '.[-1].recovery' "$fixture/import.log")
sqlite3 "$database" 'DELETE FROM preferences;'
rm -- "$fixture/data/clipboard/$text_id"
jq -nc --arg recovery "${recovery##*/}" --arg clipboard "$fixture/data/clipboard" '{recovery:$recovery,clipboard:$clipboard}' \
    > "$fixture/data/.restore-pending.json"
bash "$repo/src/services/storage/backup.sh" recover "$database"
[[ $(sqlite3 "$database" "SELECT value_json FROM preferences WHERE key='clock.showSeconds';") == false ]]
[[ $(sqlite3 "$database" 'SELECT COUNT(*) FROM clipboard;') == 0 ]]
[[ ! -e $fixture/data/.restore-pending.json ]]
printf 'PASS: interrupted filesystem/database restore recovers before storage opens\n'
