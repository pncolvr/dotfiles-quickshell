# Twitch

## Following streamers

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
channels are hidden.

## Search

Search matches streamer logins, categories, and stream titles, temporarily expanding
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

The trash button removes a streamer. A Recently removed grid offers individual
Undo buttons and **Undo all (N)**, using the same layout as suggestions. Each
removal stays available for six seconds independently and restores the streamer
with their cached avatar and schedule.
Left-click the Twitch icon to pin/unpin the
dropdown, with an accent color while pinned, as in TOTP and notifications.
Clicking a streamer's avatar or details opens their Twitch page in the default browser.
Logins are stored in lowercase and duplicates are rejected. A new database starts
with an empty list; there is no users-file import. Exported lists are ordinary text
files that you can save or share.

See [IPC](../ipc.md) for commands and exporting logins, and
[storage](../storage.md) for schedule and avatar caching.

[Documentation](../README.md)
