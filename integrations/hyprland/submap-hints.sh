#!/usr/bin/env bash
set -euo pipefail
hyprctl binds -j | jq -r --arg submap "${1:-}" '
  .[] | select(.has_description and .submap == $submap and .catch_all == false)
  | . as $bind
  | ([if (.modmask / 64 | floor % 2) == 1 then "Super" else empty end,
      if (.modmask / 8 | floor % 2) == 1 then "Alt" else empty end,
      if (.modmask / 4 | floor % 2) == 1 then "Ctrl" else empty end,
      if (.modmask % 2) == 1 then "Shift" else empty end,
      .key] | join("+")) + ";" + $bind.description'
