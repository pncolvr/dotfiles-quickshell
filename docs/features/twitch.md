# Twitch

## Following streamers

Twitch checks on startup, then at clock-aligned intervals configured by
`Config.twitchInterval` in whole minutes. Five minutes checks at :00, :05, :10,
and so on each hour. Reconnecting or changing followed streamers also checks
immediately without shifting those regular checks.

Hover the Twitch icon to see followed streamers and their next scheduled streams
in separate Live and Offline grids, each with a count. Click either heading to
collapse or expand its grid; Offline starts collapsed and Live starts expanded.
The tooltip's total height
is capped to fit the screen; streamer and suggestion grids scroll while add
controls stay visible. A divider separates the footer, where the search and add
inputs use the available width.
Click **+** to enter a streamer login or Twitch URL, then **+** or Enter to save;
**×** or Escape cancels. While adding, channels open in qutebrowser appear below
the field in a compact grid of buttons you can click to follow. Adding one keeps
the editor and search text open while other suggestions remain. **Add all (N)**
shows how many currently displayed suggestions it will follow. Already followed
channels are hidden. Suggestions are available while the optional second channel
field is empty.

## Main and second channels

Each followed streamer can have one optional second channel. The Live list shows
the main channel whenever it is live, otherwise the second channel if it is live. When
neither is live, only the main entry appears in Offline, with its next scheduled
stream. Each association counts as one entry.

The add and edit forms show the main and optional second channel fields side by
side, before the cancel and submit buttons.
Both fields accept logins or Twitch URLs. The row's edit button opens both fields
and focuses the second channel input. Clicking the same edit button again closes
the editor and discards its draft. Save applies both fields and Cancel discards
the draft. Clearing the second channel field unlinks it. When the proposed second
channel is already followed independently, **Link these entries** explicitly replaces its
separate entry with the association. Channels already used in another association
cannot be linked again, and the main cannot be its own second channel.

A second channel row uses that channel's avatar, name, category, title, and viewer
count, with a muted **Second channel for banana** label identifying its main channel. Clicking
the avatar or other details opens the displayed second channel; clicking the
**Second channel for banana** label opens banana's main channel. The row's actions always edit
or remove the main association. Second-channel switching is silent; live/offline alerts
remain tied to the main channel.

## Keyboard shortcut

Press **Meta+I**, then **T**, to select Twitch from the bar-module submap.
The submap exits immediately. `qs ipc call bar open twitch` opens the
panel on the focused monitor, focuses the search input, and moves the pointer
to the center of the Twitch icon. Repeating the shortcut refocuses
search; an open add editor is cancelled. Escape dismisses a panel opened with
this command. Keyboard focus is requested once, then returns to the panel's usual
on-demand behavior. The shortcut does not pin the panel: hover and typing keep it
open, and moving the pointer away restores normal dismissal. Click the bar icon
to pin or unpin manually. Refocusing a manually pinned panel preserves its pin.

The old streamer launcher and its automatic `twitch_online_<uid>` JSON export
are removed. qutebrowser's `,mm` (current page) and `,mM` (hinted link) still call
`launcher.sh provider media TITLE URL` for direct Twitch/YouTube playback in mpv,
including Twitch chat. That helper uses `providers/_common/utils.sh`,
qutebrowser's `scripts/url/_common.sh` for URL cleaning, and Zsh's
`scripts/default-browser/default-browser.sh` to open chat; these remain in use.
The unused `providers/media.new.sh` variant is removed.

## Search

Search matches both associated logins, categories, and stream titles, temporarily expanding
Offline to show results. See [shared panel behavior](../configuration.md#panels-and-search).

## qutebrowser suggestions

Suggestions read current tab entries from whichever of `_autosave.yml` or
`default.yml` was saved most recently in `$XDG_DATA_HOME/qutebrowser/sessions`
(defaulting to `~/.local/share/qutebrowser/sessions`). They refresh every three
seconds while the editor is open, so manually saving the default session updates
suggestions even before the next autosave. They use Bash and `yq` (the jq-compatible
YAML reader); missing or unreadable sessions simply show no suggestions.
Only the newest snapshot is read; previous browsing history is excluded.

## Removal, undo, and opening streams

The row's trash button removes a streamer and its second channel. A Recently
removed grid offers individual Undo buttons and **Undo all (N)**, using the same layout as suggestions. Each
removal stays available for six seconds independently and restores the streamer
with the association and both channels' cached avatars and schedules. Undo cannot
restore an association if one of its channels has since been followed elsewhere.
Left-click the Twitch icon to pin/unpin the
dropdown, with an accent color while pinned, as in TOTP and notifications.
Clicking a streamer's avatar or details opens their Twitch page in the default browser.
Live alerts remember the last notified stream for each followed streamer across
restarts. A new stream replaces that record, so the same stream is not announced
again after restarting the shell.
Successful refreshes also announce when a previously live streamer goes offline.
Notifications contain only login names under Live and Offline headings, with no
view button. Both types are retained in notification history.
Logins are stored in lowercase and duplicates are rejected. A new database starts
with an empty list; there is no users-file import. Exported lists are ordinary text
files of main-channel logins that you can save or share. Associations are stored
in SQLite and retained by database backups.

See [IPC](../ipc.md) for commands and exporting logins, and
[storage](../storage.md) for schedule and avatar caching.

[Documentation](../README.md)
