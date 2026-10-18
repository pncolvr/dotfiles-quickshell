#!/usr/bin/env bash
# One transient strip, never persisted. Missing capture tools use the palette.
set -euo pipefail
[[ $# == 5 && -n $1 && $2 =~ ^-?[0-9]+$ && $3 =~ ^-?[0-9]+$ && $4 =~ ^[1-9][0-9]*$ && $5 =~ ^[1-9][0-9]*$ ]] || exit 2
command -v grim >/dev/null && command -v magick >/dev/null || exit 1
# Global strip geometry already selects the monitor; grim forbids -o with -g.
timeout -k 1 3 grim -g "$2,$3 ${4}x${5}" -s 1 -t ppm - 2>/dev/null |
    magick ppm:- -alpha off -colorspace sRGB -depth 8 -format '%c' histogram:info:- |
    LC_ALL=C sort -nr |
    awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i ~ /^#[[:xdigit:]]{6}$/) print $i }'
