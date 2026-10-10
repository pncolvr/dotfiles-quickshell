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

Recent-file folder tabs, aliases and default selection use preferences. Pinned
document metadata is stored separately under `files.pinned`, so removing a folder
tab leaves its document pins intact. No schema migration is needed for document pins.

## Twitch cache

Schema version 7 adds `twitch_users.fallback_login`, defaulting existing entries to
no second channel. Main and second channels form a single followed entry; each
channel has one owner and cannot also be followed independently. Linking an existing entry
is explicit and atomic. Removing an association deletes both channels' unused
caches; Undo restores the association and cached data. Plain login exports contain
main channels only, so back up the database to preserve associations.

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

Schema version 5 adds clipboard metadata and searchable text while preserving the
existing tables. Original payload bytes live in private, content-addressed files
under `data/clipboard/`. Schema version 6 adds durable clipboard pins, defaulting
existing entries to unpinned without changing their contents. Pinned entries are
excluded from automatic pruning and Clear history. Include this directory alongside `data/quickshell.db`
when backing up clipboard history. See [launcher and clipboard](features/launcher.md).

## Backups

Stop the shell before copying `data/quickshell.db` so pending writes have finished.
Keep `data/` at the configuration root when moving or updating the source tree.
The `src/` layout does not change the database path or require a data migration.

[Documentation](README.md)
