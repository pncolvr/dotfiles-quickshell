# Browser router

This integration is optional. Set `browserRoutingEnabled: true` in Config to
activate routing and the Bookmarks / History / Manage tabs. It is enabled in this setup.
Choose a concrete browser in `webappDefaultBrowser` and configure its command
and profiles in `webappBrowsers`. Do not use `xdg-open` as the router's destination
or fallback: after activation it would call this handler again.

From the repository root, install the wrapper and desktop entry as your user:

```sh
bash integrations/browser/install.sh
```

The installer lists installed desktop applications in the WebBrowser category.
Choose a browser, then optionally enter extra arguments one per line; leave the
line empty to finish. For example, enter `--profile-directory=Personal` to select
a Chromium browser profile. Arguments are literal; do not add shell quotes.
You can also supply the fallback directly, for example
`bash integrations/browser/install.sh vivaldi --profile-directory=Personal`.
The installer writes
`~/.local/bin/quickshell-browser` and
`${XDG_DATA_HOME:-~/.local/share}/applications/quickshell-browser.desktop` with
an absolute checkout path in the wrapper; it changes no default associations.
The desktop entry runs `quickshell-browser`, so `~/.local/bin` must be in your
desktop session's `PATH`. The installer reports if it cannot find its launcher
there. Keep this checkout at the installed path, or rerun installation after
moving it. The `.desktop` file beside this README is copied by the installer.

When Quickshell is running, the handler asks its browser IPC endpoint to open
each target. With routing disabled, that endpoint uses the configured fallback
browser directly. If the endpoint is unavailable, the installed wrapper uses the
literal fallback supplied at installation. Neither fallback applies rules or
records history. Rerun installation to update its fallback command.

The wrapper accepts URLs, bare domains, local file paths and search text. The
browser decides whether to navigate or search. Quote multi-word searches so they
arrive as one argument:

```sh
~/.local/bin/quickshell-browser www.google.com
~/.local/bin/quickshell-browser 'weather tomorrow'
```

Inspect your existing defaults before changing them:

```sh
xdg-settings get default-web-browser
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
xdg-mime query default text/html
```

To choose the installed entry as the desktop's default browser:

```sh
xdg-settings set default-web-browser quickshell-browser.desktop
```

To change only HTTP/HTTPS associations, leaving local HTML file associations
alone, use this instead:

```sh
xdg-mime default quickshell-browser.desktop x-scheme-handler/http x-scheme-handler/https
```

Opening local HTML **through Bookmarks/Webapps/router commands** always uses the
selected browser, independently of the desktop's HTML association. To also open
HTML files from the file manager through the router, explicitly opt in:

```sh
xdg-mime default quickshell-browser.desktop text/html application/xhtml+xml
```

Restore your previous desktop-entry names with the same commands before removing
this integration.

## Rules and history

In Bookmarks, Manage uses the shared details/editor pane. Add a routing rule
while keeping Manage open as you interact with other applications; click the
panel to return to it. Bookmarks and History still dismiss on outside clicks.
Manage keeps the ordinary public picker window and capture visibility.
Configure a rule
with its action and match type: literal Contains, Host and subdomains, anchored
wildcards (`*` and `?`), or a regular expression. Rules run from top to bottom in
the displayed list. Select a rule and use **Move up / Move down** beside Edit to
change its order. New rules append to the end. Disabled rules are skipped.

For **Contains**, enter one value per line. The rule matches when the URL contains
any listed value. Values are literal and case-sensitive. This lets one Work rule
cover multiple destinations with the same browser, profile and workspace.

Actions are:

- **Open in browser:** choose browser/profile/window mode.
- **Follow redirects:** resolve HTTP(S) redirects with bounded request time and
  redirect count, then re-evaluate the resulting URL against the rules.
- **Unwrap query parameter:** percent-decode the named query value and re-evaluate
  the extracted HTTP(S)/file target.
- **Run application:** search the installed desktop applications or select Custom
  command to enter literal argv with `{url}` and numbered regex captures such as
  `{1}`. Selected applications keep their executable read-only; their editable
  **Target** defaults to `{url}` and can instead use a protocol prefix and capture
  groups, such as `custom://item/{1}`. The command preview follows this template.
  Optional extra arguments accept shell-style quoting for spaces, without
  shell expansion. If the selected desktop entry or executable is unavailable,
  the URL opens in the configured default browser and an alert names the application.
  No shell evaluates the expanded arguments. With **Only when application is running**
  checked, the executable's process name must be running; if it is not, the matching
  browser rule/default is used, including its workspace.

The first matching browser/application action ends routing. Transformations are
limited to eight steps and stop on cycles; an unchanged transformation is skipped
for that URL so another rule/default can handle it. Unmatched targets use the
default browser set by `Config.webappDefaultBrowser`. Explicit saved Webapp/n8n
browser choices bypass these rules. New Webapp/n8n entries use
`Config.webappDefaultBrowser`. Local HTML files are targets to open; they are not
parsed as a bookmark source. Plain-text bookmark sources retain `URL title` per line; use an
encoded `file:///...` URL for filenames containing spaces, or type an absolute
path into the picker.

History stores the last 100 distinct original targets by default in the main SQLite
backup, with an FTS5 index for search. Each row has two fixed-height lines: the
original URL above, and the browser plus matched rule chain below. Hover a row
for its full original URL, final URL, browser and rule chain. Opening an entry
routes its original URL again using the current rules. Ctrl+H opens History from Bookmarks; change
`Config.keybinds.bookmarks.history` to customize it. It is not shown in footer hints.
Matched rule names appear in the warning color beside the browser, using the
selection text color on highlighted rows. Names are
recorded when a target opens, including redirect/unwrapping chains. Renaming or
removing a rule leaves existing history labels unchanged. Reopening the same original URL
moves its entry to the top and replaces its final URL, browser and rule names with
the latest routing result. Different original URLs remain separate entries even
when they resolve to the same destination. If no rule matches on that visit, the
previous rule label is cleared.
Targets handled by the default browser without a matching rule have no rule label.
History actions open URLs, create a routing rule from the selected URL, remove
one entry or clear all entries. `browserHistoryEnabled: false` stops new recording
and retains existing history for viewing/removal. `browserHistoryLimit` controls
the bound; reducing it prunes old entries, and zero clears/stops history.

`browserWorkspaceFocusEnabled` opts into terminal rules' numbered workspace using
Hyprland Lua dispatch; zero keeps the current workspace, and
`$XDG_RUNTIME_DIR/hypr-autofocus` containing `0` suppresses switching. The switch is
enabled in this setup; rules with workspace zero keep the current workspace.
Existing browser-only rules remain browser actions without editing.

## Rule examples

These are examples to enter in Manage, not built-in behavior. Move transformation
rules above browser/application rules that also match.

| Match type | Pattern | Action | Parameter |
| --- | --- | --- | --- |
| Host and subdomains | `aka.ms` | Follow redirects | — |
| Host and subdomains | `teams.public.onecdn.static.microsoft` | Unwrap query parameter | `url` |
| Host and subdomains | `statics.teams.cdn.office.net` | Unwrap query parameter | `url` |

For Steam, choose **Regular expression** and **Run application**. Pattern:

```text
^https?://store\.steampowered\.com/app/([0-9]+)(?:/|[?#]|$)
```

Select **Steam** as the application and set **Target** to:

```text
steam://store/{1}
```

Here `{1}` is the numeric app ID captured by `([0-9]+)`. For example,
`https://store.steampowered.com/app/620/Portal_2/` becomes `steam://store/620`.
Alternatively, select **Custom command** and enter:

```sh
steam 'steam://store/{1}'
```

Check **Only when application is running** to require Steam to be running;
leave it unchecked to always dispatch the application. The condition uses `pgrep`. Set a
workspace only if wanted and enable the global workspace-focus integration.
Neither Steam nor any Microsoft host is recognized specially by the runtime.
