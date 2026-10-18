#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-fts.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/data"
ln -s "$root_dir/src" "$fixture/src"
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/migration.qml" > "$fixture/shell.qml"
run() {
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
        QT_QPA_PLATFORM=offscreen timeout 10 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; return 1; }
    rg -q 'PASS: FTS migration' "$fixture/log"
    ! rg -q 'FTS FAIL:|TypeError:|ReferenceError:|Binding loop' "$fixture/log"
    ! rg -qi 'PRIVATE_CLIPBOARD_SENTINEL|PRIVATE_SCHEMA_SENTINEL' "$fixture/log"
}
run
db=$fixture/data/quickshell.db
[[ $(stat -c %a "$db") == 600 && $(stat -c %a "$fixture/data") == 700 ]]
# Use a real full schema-10 fixture, retaining existing records and pins.
sqlite3 "$db" <<'SQL'
DROP TRIGGER clipboard_fts_insert; DROP TRIGGER clipboard_fts_delete; DROP TRIGGER clipboard_fts_update;
DROP TABLE clipboard_fts;
UPDATE clipboard SET text='legacy alpha',pinned=1;
PRAGMA user_version=10;
SQL
FTS_EXPECT_LEGACY=1 run
[[ $(sqlite3 "$db" 'PRAGMA user_version; PRAGMA integrity_check; SELECT pinned FROM clipboard;') == $'16\nok\n1' ]]
query() { jq -nc --arg query "$1" --arg engine "${2:-indexed}" '{query:$query,engine:$engine,kind:"",pinned:false,limit:51,offset:0}' | bash "$root_dir/src/services/clipboard/query.sh" "$db"; }
query bet | jq -e '.error=="" and (.rows|length)==1 and (.rows[0]|has("search")|not) and (.rows[0]|has("text")|not)' >/dev/null
query alpha | jq -e '.rows==[]' >/dev/null
query '" OR beta --' | jq -e '.error==""' >/dev/null
query "');DROP TABLE clipboard;--" | jq -e '.error==""' >/dev/null
[[ $(sqlite3 "$db" 'SELECT count(*) FROM clipboard;') == 1 ]]
query '---' | jq -e '.rows==[] and .error==""' >/dev/null
query '' fuzzy | jq -e '.rows[0].search=="replacement beta"' >/dev/null
# Literal Unicode/punctuation matching and composing source criteria.
sqlite3 "$db" <<'SQL'
INSERT INTO clipboard VALUES(printf('%064x',10000),'text/plain','text',80,'Café résumé Ελληνικά 東京 https://example.test/path',2,0);
INSERT INTO clipboard VALUES(printf('%064x',10001),'image/png','image',100,'',3,1);
SQL
for term in cafe resume 'résumé' Ελλην 東京 'https://example.test'; do
    query "$term" | jq -e '.error=="" and (.rows|length)==1' >/dev/null
done
jq -nc '{engine:"indexed",query:"",kind:"image",pinned:true,limit:51,offset:0}' |
    bash "$root_dir/src/services/clipboard/query.sh" "$db" | jq -e '(.rows|length)==1 and .rows[0].kind=="image" and .rows[0].pinned==1' >/dev/null

# Missing derived index has a clear error; fuzzy remains usable without it.
sqlite3 "$db" 'DROP TRIGGER clipboard_fts_insert; DROP TRIGGER clipboard_fts_delete; DROP TRIGGER clipboard_fts_update; DROP TABLE clipboard_fts;'
if query beta > "$fixture/error"; then exit 1; fi
jq -e '.error!=""' "$fixture/error" >/dev/null
query '' fuzzy | jq -e '(.rows|length)==3' >/dev/null
run
# Pins can exceed the retention count; fuzzy must not silently cap their snapshot.
sqlite3 "$db" <<'SQL'
WITH RECURSIVE numbers(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM numbers WHERE x<1001)
INSERT INTO clipboard SELECT printf('%064x',x+20000),'text/plain','text',1,'pinned',x+100,1 FROM numbers;
SQL
query '' fuzzy | jq -e '(.rows|length)==1004' >/dev/null

# Delete and rollback update the actual index, not just external-content SELECTs.
sqlite3 "$db" "BEGIN; DELETE FROM clipboard; ROLLBACK; INSERT INTO clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1); DELETE FROM clipboard;"
query beta | jq -e '.rows==[]' >/dev/null
retained_tables=$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'clipboard_fts%' ORDER BY name;")
sqlite3 "$db" <<'SQL'
INSERT INTO clipboard VALUES(printf('%064x',90000),'text/plain','text',8,'rollback',1,1);
BEGIN IMMEDIATE;
DROP TRIGGER clipboard_fts_insert;
DROP TRIGGER clipboard_fts_delete;
DROP TRIGGER clipboard_fts_update;
DROP TABLE clipboard_fts;
DROP INDEX clipboard_kind_time;
PRAGMA user_version=10;
COMMIT;
SQL
[[ $(sqlite3 "$db" "PRAGMA user_version; PRAGMA integrity_check; SELECT text,pinned FROM clipboard;") == $'10\nok\nrollback|1' ]]
[[ $(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'clipboard_fts%' ORDER BY name;") == "$retained_tables" ]]
printf 'PASS: FTS migration, pins, update/touch/rollback, deletion, literal queries, metadata-only reads, permissions and index recovery\n'
