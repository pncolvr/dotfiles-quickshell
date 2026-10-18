# Storage

## Database location

`DbService` owns a versioned SQLite database, with separate repositories for Twitch
users, schedules and avatar images, Logitech receiver battery snapshots, and user preferences.
The clock's seconds toggle is saved across restarts. Quickshell creates
`data/quickshell.db` inside this config on first run. The data folder is ignored
by Git apart from its empty-directory marker; no database is shipped in the
repository. `DbService` uses native SQLite `ATTACH` to open that path through
Qt Quick LocalStorage. Qt keeps an empty connection database in its default
storage directory; all application tables and schema versioning live in
`data/quickshell.db`. No preparation script is needed. `Config.databasePath`
uses `Quickshell.shellPath("data/quickshell.db")` and `Config.databaseName` is
the fixed name `quickshell`. Tests run their entrypoint in a temporary config
folder so their databases stay isolated.

Schema 16 adds browser routing rules and history keyed by the original target.
Each entry retains its final URL, browser and matched rule names. History has an
external-content FTS5 index maintained transactionally by triggers. Rules and
retained history are part of the existing encrypted backup.
Older supported backups acquire these tables when opened by the current shell.

Recent-file folder tabs, aliases and default selection use preferences. Pinned
document metadata is stored separately under `files.pinned`, so removing a folder
tab leaves its document pins intact. No schema migration is needed for document pins.

## Directories

Schema version 9 adds `directories`, keyed by canonical folder path or a
file-manager URI, with a display name and explicit Personal/Work category.
Editing changes all fields atomically; removing an entry never deletes files.
There is no runtime JSON import. Both pickers retain their existing records when
the database schema upgrades.

## Projects

Schema version 8 adds `project_sources`, `projects`, and `project_workspaces`.
Sources hold canonical paths, root/single-folder kinds, explicit categories and
scan status. Projects retain names and remote URLs per source. Workspace records
retain both included and excluded choices per project path. Overlapping sources
are deduplicated for display; removing one preserves projects owned by another.
Reload groups source owners and workspaces once by project path. Single-folder
sources retain metadata priority, every owner remains available to source editing,
and project/workspace sorting and inclusion flags are preserved.
Refresh replaces successful source snapshots transactionally, preserving existing
workspace choices. Newly discovered workspaces require an inclusion checklist
before the refreshed snapshot is saved; cancelling retains the previous snapshot.
Failed sources
retain their previous data. No project JSON import or generated cache is used.

## Twitch cache

Schema version 7 adds `twitch_users.fallback_login`, defaulting existing entries to
no second channel. Main and second channels form a single followed entry; each
channel has one owner and cannot also be followed independently. Linking an existing entry
is explicit and atomic. Removing an association deletes both channels' unused
caches; Undo restores the association and cached data. Full-state backups preserve
the users, associations and caches together.

Twitch schedules store absolute start times and refresh at most hourly while
cached, or sooner once the cached start has passed. Relative labels update with
the clock, including across midnight. Failed requests preserve the previous
cache. Avatar image payloads are stored as base64 data URLs in SQLite and displayed
directly by QML. A changed profile-image URL refreshes the cached image; failed
downloads retain the previous one. Removing a streamer deletes its schedule and
avatar too. Schema version 4 adds `twitch_notified_streams`, with only one stream ID
per followed streamer, plus its latest online/offline flag. New live alerts replace
that ID; removing a streamer deletes it, and Undo restores it. The panel reads the
service directly; no automatic picker JSON file is written.

## Notification history

Schema version 3 adds saved action metadata to the history, emitter preferences
and reload metadata introduced in version 2, without replacing existing Twitch/battery/preferences tables. Image snapshots are stored
as PNG data URLs in SQLite. QML renders provider images outside the bar viewport;
the Bash helper uses `stat`, `od` and `base64` to validate, encode and remove the
temporary PNG. No extra notification-center package is needed. History and emitter
settings are local to `data/quickshell.db`.

TOTP names and seeds live in the desktop Secret Service; see [TOTP](features/totp.md).

## Clipboard history

Schema version 11 adds a rebuildable external-content FTS5 index. The clipboard
table and exact payload bytes are preserved; stable-rowid UPSERT and transactional
triggers keep search consistent with updates/deletion. Pin/recency changes avoid
reindexing text. Indexed result pages contain short previews and metadata, while
the optional fuzzy engine reads full searchable text. See [index maintenance,
backup and rollback](clipboard-index.md). Database setup now prepares private
permissions before opening; repositories reload once storage is ready.

Schema version 5 adds clipboard metadata and searchable text while preserving the
existing tables. Original payload bytes live in private, content-addressed files
under `data/clipboard/`. Schema version 6 adds durable clipboard pins, defaulting
existing entries to unpinned without changing their contents. Pinned entries are
excluded from automatic pruning and Clear history. Include this directory alongside `data/quickshell.db`
when backing up clipboard history. See [launcher and clipboard](features/launcher.md).

Schema version 10 adds an index on clipboard timestamps and IDs, so opening
history does not need to sort the table. Existing entries, pins and payloads are preserved.

## Backups

Use `qs ipc call backup create /absolute/path/backup.7z` to open the existing private
secret picker. Choose a password, or use Generate, then Copy to save it elsewhere.
The prompt has Generate and Copy buttons plus keyboard hints. Enter creates the
archive; Escape cancels without starting the backup. The destination folder must
already exist, be writable and owned by your user, and not itself be a symlink. Both a
password and the TOTP collection are required; an empty collection is preserved.
The database includes Twitch associations, preferences, projects, directories,
notification history and clipboard metadata. Original clipboard payloads and a
versioned `totp.json` are included, with checksums and a format/schema manifest.

The Bash helper uses 7-Zip (`7z` or `7zz`), `sqlite3`, `jq`, coreutils and util-linux.
7z data and filenames are encrypted. Passwords travel through pipes, never argv;
TOTP JSON stays in memory and an unlinked tmpfs descriptor while archiving, never
in a named plaintext file. The keyring helper uses the configured desktop Secret
Service namespace. Backups do not export the rbw vault or other applications' secrets.
Save the backup password separately. Existing destination files are never overwritten.

`qs ipc call backup restore /absolute/path/backup.7z` prompts for the password,
validates the archive layout, encrypted entries, size, checksums, database integrity
and clipboard payloads, then replaces saved data and this TOTP namespace. Unrelated
keyring entries are untouched. Restore accepts schema 6 through the current schema;
startup applies existing migrations for older supported backups. The helper limits
archives to 8 GiB of uncompressed content and 100,000 entries.

Clipboard operations and database writes pause while the helper runs; in-flight
clipboard/TOTP work finishes first. SQLite's backup API snapshots and restores the
database without replacing its open file. A successful restore reloads the shell
before writes resume. The `backup` bar alert shows the current stage and result;
it appears below the bar's right edge, including over fullscreen applications.
Successful creation shows "Backup created:" and the saved path for 15 seconds;
errors expire after 1 minute and can be cleared sooner by dismissal, another attempt or reload.
`qs ipc call backup status` exposes progress/errors: `busy` is true while working,
`completed` is true after a successful operation, and `output` is the saved export
path. A false `busy` alone does not mean success; check `completed` and `error`.
These operation fields last until the next attempt or reload. Its `report` contains the last
successful import's archive/recovery paths, completion time, unavailable entries,
unchecked locations and counts, and survives reload/restart through preferences.
The result alert is shown once after the automatic reload.

Restore keeps every saved project, source, workspace and directory even when its
path is unavailable on the current machine. A read-only batch check reports missing
or inaccessible local folders and workspace files; remote/virtual URIs are marked
"Location not checked". Import succeeds with warnings instead of deleting entries,
cloning repositories, creating folders or mounting volumes. Checks that time out
are also reported as not checked. Inspect details with:

```sh
qs ipc call backup status | jq '.report'
```

Projects and Directories Manage lists check paths when opened and after changes
to their saved records while managing. Missing paths have a warning below their
existing labels; workspace warnings appear in project summaries and the workspace
editor. Reopen Manage after recreating a folder or mounting its drive to clear the
availability warning. Edit and Remove remain available. The import report records
the situation at import time; it does not change when paths later return.

Before replacing anything, restore saves the current database and clipboard files
under `data/backup-recovery.XXXXXXXX/`. These are private, unencrypted local recovery
copies and do not contain TOTP JSON. Failed restores compensate keyring writes and
restore the previous database/payloads. Secret Service has no multi-item transaction:
keyring rollback can fail, and an abrupt kill or power loss may leave partial TOTP
changes. Unlock the keyring and import the encrypted backup again in that case.
A startup journal recovers interrupted database/payload changes before Qt opens
storage. Keep recovery copies until satisfied with the restore; remove them manually
when no longer needed.

For a manual file backup, stop the shell before copying `data/quickshell.db` and
`data/clipboard/` together so pending writes have finished. This does not include TOTP.
Keep `data/` at the configuration root when moving or updating the source tree.
The `src/` layout does not change the database path or require a data migration.

## Manual backup and recovery test

Use two encrypted backups for a real round trip. The second preserves the state
you want to return to, including TOTP secrets; the local database/clipboard
recovery copy alone cannot recover previous TOTP entries after a process crash.
Keep both archive passwords somewhere you can retrieve independently of this shell.

1. Reload the shell with `qs ipc call shell reload`. In the repository root, create
   an empty test folder with `mkdir -p data/manual-backup-test/folder`. Add that folder
   to Directories through Manage, named "Manual backup test". Note whether the clock
   currently shows seconds.
2. Run `qs ipc call backup create "$PWD/data/manual-before.7z"`. Enter a password
   (or Generate and Copy), press Enter, and wait for "backup created". These example
   filenames must be new; use different names if they already exist.
3. Run `rmdir data/manual-backup-test/folder` and click the clock once to toggle
   seconds. Reopen Directories Manage and check the missing-folder warning. Create
   the return-point archive with `qs ipc call backup create "$PWD/data/manual-return.7z"`.
   Wait for success before continuing.
4. Run `qs ipc call backup restore "$PWD/data/manual-before.7z"` and enter its password.
   After reload, seconds should match step 1, the directory entry should still be
   saved with its warning, and `qs ipc call backup status | jq '.report'` should
   include the missing test folder. The backup restores references, not the folder.
   Check that your TOTP entries still appear.
5. Run `qs ipc call backup restore "$PWD/data/manual-return.7z"`. After reload,
   seconds should return to the setting captured in step 3. This exercises recovery
   to the state saved immediately before the first restore, including its keyring data.
6. Recreate the test folder, reopen Manage and check that the availability warning
   clears. Remove the test entry through Manage when finished. Keep the archives
   and `data/backup-recovery.*` copies until satisfied with the result.

This tests the real encrypted backup/restore path. Crash-interruption recovery is
tested separately with isolated data; the manual sequence does not force-kill the
live shell or require deleting its database.

[Documentation](README.md)
