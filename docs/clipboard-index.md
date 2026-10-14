# Clipboard index maintenance

Clipboard schema 11 adds a derived FTS5 index over text and MIME metadata. The
clipboard table and payload files remain authoritative. Inserts, content changes
and removals update the index transactionally. Pin and recency changes do not
reindex text. Indexed search is case-insensitive literal word/prefix matching;
FTS operators typed into the search field are treated as ordinary words.
Fuzzy search remains an explicit option and needs the complete searchable history.

Qt SQLite and the sqlite3 runtime helper must support FTS5 and SQLite 3.42 or newer
for the index's secure-delete setting. Queries use a read-only connection, fixed
SQL templates and stdin/stdout. Search strings and results are not command-line
arguments or application log messages. Background failures disable entry activation
and show a fixed diagnostic; they do not clear the history. The derived index is
rebuildable. Missing index tables are rebuilt at startup.

The first migration backfills the index atomically before storage becomes ready.
A synthetic 1,000-row/500 MB history took approximately 12 seconds to rebuild on
the development machine, and a ranked page through the helper took about 0.37
seconds. These are measurements, not promised latency. No WAL policy is changed.
Close the shell before maintenance on a large history; do not backfill a live
partially indexed table. Data directories are created privately (700), with the
owned database and existing journal/WAL sidecars set to 600 before opening.
SQLite and FTS secure-delete are deletion hygiene, not encryption or backup erasure.

## Backup and rollback

Stop the shell before copying the database and `data/clipboard/` together. Keep
backups in a private directory. A consistent backup is necessary for restoration,
since deleting or pruning entries also removes payload files. Do not overwrite an
open database. Implementation backup locations are recorded in the local plan,
not committed into configuration.

To roll back to schema-10 application code, restore its matching database/payload
backup with the shell stopped. Alternatively, the additive derived index can be
removed from a copied database before use with old code:

```sql
BEGIN IMMEDIATE;
DROP TRIGGER IF EXISTS clipboard_fts_insert;
DROP TRIGGER IF EXISTS clipboard_fts_delete;
DROP TRIGGER IF EXISTS clipboard_fts_update;
DROP TABLE IF EXISTS clipboard_fts;
DROP INDEX IF EXISTS clipboard_kind_time;
PRAGMA user_version=10;
COMMIT;
```

For a suspected damaged index, keep a backup and rebuild with the shell stopped:

```sql
BEGIN IMMEDIATE;
INSERT INTO clipboard_fts(clipboard_fts) VALUES('rebuild');
INSERT INTO clipboard_fts(clipboard_fts,rank) VALUES('integrity-check',1);
COMMIT;
```

Both snippets are for the config-local database itself, without the Qt `store`
attachment prefix. Fuzzy mode can still query a readable clipboard table when an
indexed query fails. General SQLite integrity should also pass before reopening.
Secrets from Vault and TOTP are never added to this index.

Database failure logs report a fixed operation/category and, for recognized
constraint failures, an allowlisted table/column name. Raw SQLite messages,
SQL statements and clipboard text are never logged. Image capture uses an empty
text field; its JSON-decoded Qt value is normalized with COALESCE before insertion
to avoid a non-null constraint failure.
