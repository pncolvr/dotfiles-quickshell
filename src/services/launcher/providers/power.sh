#!/usr/bin/env bash
# Noninteractive command execution, including idle locking without a running bar.
set -euo pipefail
provider_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_root=$(cd -- "$provider_dir/../../../.." && pwd)
ipc() { "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "${QS_PICKER_CONFIG:-$config_root}" call "$@"; }
if (($# == 0)); then
    exec "${QS_PICKER_EXECUTABLE:-qs}" ipc -p "${QS_PICKER_CONFIG:-$config_root}" call launcher power
fi
native=false
if [[ $1 == --execute ]]; then native=true; shift; fi
(($# == 1)) || exit 2
# The native service pauses tracking directly. External callers retain the old
# best-effort notification, and still execute when Quickshell is unavailable.
case $1 in
    Reboot)   power_command=(systemctl reboot) ;;
    Lock)     power_command=(loginctl lock-session) ;;
    Logout)   power_command=(hyprctl dispatch exit) ;;
    Shutdown) power_command=(systemctl poweroff) ;;
    Bios)     power_command=(systemctl reboot --firmware-setup) ;;
    *) exit 2 ;;
esac
if ! $native; then ipc status pause >/dev/null 2>&1 || true; fi
exec "${power_command[@]}"
