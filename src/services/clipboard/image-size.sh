#!/usr/bin/env bash
# Header metadata only; never print decoder errors or image contents.
set -euo pipefail
umask 077
image_path=${1:?}
[[ -f $image_path ]]
# Inspect the first frame without decoding a full-resolution bitmap.
exec timeout 3 magick identify -ping -format '%w %h\n' -- "${image_path}[0]" 2>/dev/null
