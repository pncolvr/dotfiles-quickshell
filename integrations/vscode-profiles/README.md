# VS Code: one account per profile

VS Code profiles (`--profile Work`) keep settings and extensions apart, but every
sign-in is stored once per *data dir* (`~/.config/Code`), so all profiles share
the same GitHub/Microsoft accounts. This integration gives selected profiles their
own data dir, and with it their own sign-ins, while keeping the profile names you
already use.

## How a project gets its account

```
project picker → category (work/personal)
  → profile name from Config.qml projectApps.code.profiles   ("Work")
  → code-profile.sh <path> --profile Work
  → ~/.local/share/vscode-profiles/work/User exists?
       yes → code --user-data-dir ~/.local/share/vscode-profiles/work
                  --extensions-dir ~/.local/share/vscode-profiles/work/extensions <path> --profile Work
       no  → code <path> --profile Work        (shared ~/.config/Code, as before)
```

- The launcher always goes through
  [`src/services/projects/code-profile.sh`](../../src/services/projects/code-profile.sh)
  (set as `command` of the `code` entry in `src/config/Config.qml`). With no seeded
  dir it behaves exactly like `code`.
- Profile names map to dir names by lowercasing and replacing other characters
  with `-`: `Work` → `work`, `Client A` → `client-a`.
- `--profile` is only added when `workModeEnabled` is on. With work mode off,
  every project opens in `~/.config/Code`.
- An explicit `--user-data-dir` or `--extensions-dir` in the arguments is always
  respected. `--extensions-dir` is only added when the dir has an `extensions/`
  folder (seeded before that existed? see [below](#troubleshooting-extensions)).
- **The fallback is silent.** A missing or misspelled dir opens the shared
  account without a warning. Check the Accounts menu if in doubt.

Data dirs live in `~/.local/share/vscode-profiles/` (`$VSCODE_PROFILES_ROOT`
overrides this for all scripts).

## Setup

Seeding is manual; nothing creates data dirs on its own. Run from the repo root.

**1. Seed a data dir per account.** Close VS Code windows using those profiles
first. The source is only read.

```sh
bash integrations/vscode-profiles/seed.sh --dry-run Work Personal   # preview
bash integrations/vscode-profiles/seed.sh --workspaces ~/Projects/green-one Work
bash integrations/vscode-profiles/seed.sh --workspaces ~/Projects/personal Personal
```

**2. Sign in once per dir.**

```sh
bash src/services/projects/code-profile.sh --profile Work
```

Sign in from the Accounts menu. The browser's `vscode://` callback may land in a
different VS Code instance. If the login never arrives, dismiss the redirect
prompts until VS Code offers a device code and enter that in the browser instead.
Re-add MSSQL, Azure and MCP credentials as needed.

Enable Settings Sync in at most one dir per GitHub account, otherwise the dirs
overwrite each other's settings.

**3. Optional: app menu entries.**

```sh
bash integrations/vscode-profiles/install-desktop.sh Work Personal   # adds "Code (Work)", ...
```

Git commit identity and SSH keys are not handled by VS Code. For per-account
identities use `includeIf "gitdir:~/Projects/green-one/"` blocks in `~/.gitconfig`.

## What seeding copies

A seeded dir contains a single profile with the same name, so `--profile Work`
keeps working inside it. The profile reuses the source's internal folder id, or
gets a new random one when the source is `Default`.

| Copied | Not copied |
|---|---|
| Default and profile `settings.json`, `keybindings.json`, `tasks.json` | Secrets and sign-ins |
| `mcp.json`, `chatLanguageModels.json`, snippets, prompts | Cookies and web storage |
| The profile's extension list and those extensions, into `<dir>/extensions/` | Settings Sync state |
| Extension state DB, with auth/account/token/session/sync/telemetry keys deleted and the DB `VACUUM`ed | Machine and telemetry ids |
| With `--workspaces PATH`: per-workspace UI state for folders under PATH | Caches, logs, backups, local file history |
| With `--extension-storage`: extension storage folders, except auth-related ones | |

Each data dir gets its own extensions folder, `<dir>/extensions/`. The listed
extensions are hard-linked from the source's folder (`~/.vscode/extensions`), so
seeding takes almost no extra space; after that each dir installs and updates on
its own. Sharing one folder does not work: every VS Code instance deletes
extensions that none of the profiles in *its* data dir list, including ones
another dir still uses. `~/.vscode/argv.json` (`password-store: basic`) stays
shared.

## Seeding options

Each profile argument says **what to create** and **where to copy it from**:

```text
PROFILE[=DIR:SOURCE]
```

- `PROFILE` names the new account and the profile inside its data dir. Its dir
  name is a lowercase slug, such as `Contractor` → `contractor/`.
- `SOURCE` names the existing VS Code profile to copy. If omitted, it defaults
  to `PROFILE`.
- `DIR` optionally selects which VS Code data dir contains that source profile.
  It can be a path or the name of an account dir already under the profiles
  root. If omitted, the script uses `--source` (by default `~/.config/Code`).
- Use `Default` for the default profile. Quote paths with spaces as normal for
  your shell.

So, `Contractor=acme:Acme` means: create the `contractor/` data dir, and copy
profile `Acme` from the existing `acme/` data dir.

### Choose the source

Assume `Acme` is an existing profile in `~/.config/Code`, and an earlier
`seed.sh Acme` created the `acme/` data dir:

| Command | Source used to create the new data dir |
|---|---|
| `seed.sh Acme` | Profile `Acme` in `~/.config/Code` → `acme/` |
| `seed.sh Contractor=Acme` | Profile `Acme` in `~/.config/Code` → `contractor/` |
| `seed.sh Contractor=acme:Acme` | Profile `Acme` in `acme/` → `contractor/` |
| `seed.sh Lab="$HOME/.config/Code - OSS":Default` | Default profile in Code - OSS → `lab/` |
| `seed.sh --source "$HOME/.config/Code - OSS" Acme Lab=Default` | Profiles `Acme` and `Default` in Code - OSS → `acme/` and `lab/` |

An explicit `DIR:` applies to that one profile argument and takes precedence
over `--source`.

To also copy per-workspace UI state (open editors and layout) for workspaces
under selected folders, pass `--workspaces PATH`. Repeat the option for more
folders:

```sh
seed.sh --workspaces ~/Projects/green-one Contractor=Acme
seed.sh --workspaces ~/Projects/green-one --workspaces ~/Projects/lab Lab
```

### Refresh an existing data dir

`--update` copies configuration into a data dir that was already seeded. It
does not create the dir. It refreshes config files, while keeping that target's
sign-ins, extension state database, and extension list:

```sh
seed.sh --update Acme                    # refresh acme/ from ~/.config/Code
seed.sh --update Contractor=acme:Acme    # refresh contractor/ from profile Acme in acme/
```

See `seed.sh --help` for optional settings such as `--workspaces`,
`--extension-storage`, and `--no-state`, and for all defaults.

## Removing an account

```sh
rm -rf ~/.local/share/vscode-profiles/<slug>
bash integrations/vscode-profiles/install-desktop.sh --remove PROFILE
```

Projects for that profile then fall back to `~/.config/Code`. To drop the
integration entirely, set `command: ["code"]` in `src/config/Config.qml`.

## Troubleshooting extensions

Reinstall from the Extensions view, or:
`code-profile.sh --profile NAME --install-extension ID --force`.

- **Marked installed but doesn't load.** The source used a different extensions
  folder (Code - OSS uses `~/.vscode-oss/extensions`), or the extension keeps
  setup data in storage that wasn't copied.
- **`Unable to read file '~/.vscode/extensions/<ext>/package.json'`, or
  extensions disappearing after using another dir.** The dir was seeded before it
  had its own `extensions/` folder, so it shares `~/.vscode/extensions` with the
  other dirs, and each instance deletes what its own profiles don't list. Close
  its VS Code windows and run `seed.sh --update PROFILE`: it copies what is still
  there and drops what is already gone from the list, printing what to reinstall.
- **Signed out.** Extensions with their own login (Copilot, GitHub Pull Requests,
  Azure, MSSQL) need a fresh sign-in in each dir.
