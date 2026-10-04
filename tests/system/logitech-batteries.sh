#!/usr/bin/env bash
# Public Solaar report fixtures; no hardware access.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$project_root/services/system/logitech-batteries.sh"
test_dir=$(mktemp -d /tmp/quickshell-battery-reader-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
export BATTERY_SYSFS_ROOT=$test_dir/sys
mkdir -p "$BATTERY_SYSFS_ROOT/class/hidraw/hidraw11/device/power_supply/hidpp_battery_0"

devices=$(parse_devices <<'REPORT'
solaar version 1.1.20
Lightspeed Receiver
  Device path  : /dev/hidraw9
  1: PRO X Wireless
     Device path  : /dev/hidraw11
     Serial number: 4490D46D
            Battery: 91%, BatteryStatus.DISCHARGING.
     Battery: 91%, BatteryStatus.DISCHARGING.
Bolt Receiver
  2: ERGO M575S Trackball
     Device path  : None
     Serial number: 9446D807
     Battery: 20%, BatteryStatus.DISCHARGING.
Lightspeed Headset Receiver
  1: PRO X 2 LIGHTSPEED
     Device path  : /dev/hidraw5
     Serial number: 2324MH00APE8
     Battery: 95%, BatteryStatus.DISCHARGING.
  2: Sleeping mouse
     Device is offline.
     Battery: unknown (device is offline).
  3: Charging headset
     Serial number: headset-2
     Battery: 25% 3800mV , BatteryStatus.RECHARGING, next level 50%.
  4: Full headset
     Serial number: headset-3
     Battery: 100%, BatteryStatus.FULL.
  5: Battery without level
     Serial number: unknown-level
     Battery: N/A, BatteryStatus.DISCHARGING.
Direct USB mouse
     Device path  : /dev/hidraw15
     Serial number: direct-mouse
     Battery: 50%, discharging.
REPORT
)
jq -e '
    length == 7
    and any(.[]; .name == "PRO X Wireless" and .percentage == 91 and .nativePath == "hidpp_battery_0")
    and any(.[]; .name == "ERGO M575S Trackball" and .percentage == 20)
    and any(.[]; .name == "PRO X 2 LIGHTSPEED" and .percentage == 95)
    and any(.[]; .name == "Charging headset" and .state == "charging" and .pluggedIn and .percentage == 25)
    and any(.[]; .name == "Full headset" and .state == "charged" and .pluggedIn)
    and any(.[]; .name == "Battery without level" and .percentage == null)
    and any(.[]; .name == "Direct USB mouse" and .state == "discharging")
' <<< "$devices" >/dev/null
[[ $(parse_devices <<< '') == '[]' ]]
printf 'PASS: Bash Solaar reader includes mice/headsets, charging, unknown levels, excludes offline devices, and resolves kernel identity\n'
