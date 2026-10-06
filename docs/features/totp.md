# TOTP

## Dependencies

The TOTP module stores each name and seed together in the desktop Secret Service. Its
UI is native QML; a Bash helper uses `secret-tool`, `jq`, and `oathtool`. On Arch:

```sh
sudo pacman -S --needed libsecret jq oath-toolkit
```

## Managing tokens

Run a Secret Service provider such as GNOME Keyring, or enable Secret Service support
in KeePassXC. Hover the key icon, click **+**, enter a name and a Base32 seed or an
`otpauth://totp/…` URI, then click **+** again. Copy a seed from Bitwarden manually;
this module uses its own keyring entries and does not synchronize with Bitwarden.
The pencil edits both fields, **✓** saves, and **×** cancels. Enter submits the token
field; Escape cancels. The trash button deletes the entry immediately.
Click the key icon to pin the panel open; click again to return to hover behavior.
The icon uses the accent color while pinned.
The TOTP panel uses the same `quickshell-private` capture rule as notifications,
so it remains visible locally while excluded from screen sharing.

## Codes and countdown

Tokens support SHA1, SHA256, SHA512, 6–8 digits, and custom periods from TOTP URIs.
Bare seeds use the defaults in `src/config/Config.qml` (SHA1, six digits, 30 seconds).
When a visible code changes, its digits briefly roll into the new value. The
animation runs only during the transition and skips hidden rows and editing.
Copying always uses the current code, including while the digits are rolling.
The countdown sits between the list and bottom controls, with seconds on the left
and a line that empties from right to left. It is hidden when the list is empty.
The list reserves `totpListMinRows` rows (nine by default) and grows up to 45%
of the current monitor height, with a scrollbar when needed.
Adding a token uses a reserved footer row so the popup height stays stable.

## Configuration and secrets

Commands, keyring namespace, timing, and the height fraction are in `Config.qml`;
glyphs, sizes, spacing, and colors are in `src/theme/Theme.qml`. Keyring attributes are
`application=quickshell`, `type=totp`, `vault=<totpVault>`, and `id=<entry UUID>`.
Names and seeds are inside each item's secret payload. Secrets travel through
pipes, never command arguments or plaintext config files. Closing the tooltip
stops updates, clears its model, and exits the helper after any pending write.
The copied code remains on the clipboard until it is replaced.

See [setup](../setup.md#screen-sharing) for the private capture rule and
[development](../development.md#totp) for isolated verification.

[Documentation](../README.md)
