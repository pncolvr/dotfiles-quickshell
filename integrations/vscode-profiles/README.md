# VS Code: one data dir per account

VS Code profiles (`--profile Work`) separate settings and extensions, but every
sign-in and secret is stored once, in `~/.config/Code/User/globalStorage/state.vscdb`,
and shared by all profiles. To use a different GitHub account per profile, each
account needs its own `--user-data-dir`. These scripts add that on top of the
current profiles without replacing them. Nothing here runs automatically.

| Script | Purpose |
|---|---|
| `seed.sh PROFILE[=SOURCE] ...` | Creates `~/.local/share/vscode-profiles/<slug>/` per profile, copying settings but no login data. |
| `src/services/projects/code-profile.sh [code args]` | Drop-in for `code`. With `--profile NAME` and a seeded dir for NAME, adds `--user-data-dir`. Otherwise runs plain `code`. |
| `install-desktop.sh [--remove] PROFILE ...` | Adds a `Code (PROFILE)` app menu entry per profile. |

`VSCODE_PROFILES_ROOT` overrides the parent directory for all three scripts.
Profile names map to directory names: `Work` becomes `work`, `Client A` becomes `client-a`.

## 1. Seed

Close the VS Code windows for those profiles first; the source dir is only read.

```sh
bash integrations/vscode-profiles/seed.sh --dry-run Work Personal
bash integrations/vscode-profiles/seed.sh --workspaces ~/Projects/bizdocs Work
bash integrations/vscode-profiles/seed.sh --workspaces ~/Projects/personal Personal
```

Later accounts: `seed.sh Client=Work` creates a `Client` account from Work's
settings. `seed.sh --update Work` re-copies settings into an existing dir, keeping
its sign-ins, state and extension list.

Copied: default and profile `settings.json`, `keybindings.json`, `tasks.json`,
`mcp.json`, `chatLanguageModels.json`, snippets, prompts, the profile's extension
list, and extension state with auth, account, token, session, Settings Sync and
telemetry keys removed (then `VACUUM`ed). `--workspaces` adds per-workspace UI
state; `--extension-storage` adds extension folders, skipping auth-related ones.

Not copied: secrets, cookies, web storage, Settings Sync, machine and telemetry
ids, caches, logs, backups and local file history. Extensions stay installed once in
`~/.vscode/extensions`, shared by every dir, as does `~/.vscode/argv.json`
(`password-store: basic`).

## 2. Sign in once per account

```sh
bash src/services/projects/code-profile.sh --profile Work
```

Sign in from the Accounts menu. The browser's `vscode://` callback goes to whichever
VS Code instance the system picks, which is often the wrong one. If the login does
not arrive, cancel the redirect prompts until VS Code offers a device code, then
enter it in the browser. Re-add MSSQL, Azure and MCP credentials where needed.

Turn Settings Sync on in at most one dir per GitHub account, otherwise the dirs
overwrite each other's settings.

## 3. Projects launcher

`src/config/Config.qml` routes the `code` entry in `projectApps` through the wrapper:

```qml
command: ["bash", Quickshell.shellPath("src/services/projects/code-profile.sh")],
```

`profiles` and `profileArguments: ["--profile", "{profile}"]` stay as they are. A
category whose profile has a seeded dir opens in that dir; any other category,
and every project when `workModeEnabled` is off, opens in `~/.config/Code` as
before. Window reuse is unaffected because the window class is still `code`. To
undo, restore `command: ["code"]`.

## 4. Optional

```sh
bash integrations/vscode-profiles/install-desktop.sh Work Personal
```

Git commit identity and SSH keys are separate from VS Code. To use per-account
identities, add `includeIf "gitdir:~/Projects/bizdocs/"` blocks to `~/.gitconfig`.

To remove an account dir: `rm -rf ~/.local/share/vscode-profiles/<slug>` and
`install-desktop.sh --remove PROFILE`.
