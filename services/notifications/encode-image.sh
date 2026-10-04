#!/usr/bin/env bash
# Move a rendered PNG into the archive as a data URL, then remove the temporary file.
set -euo pipefail

image_path=${1:?PNG path required}
trap 'rm -f -- "$image_path"' EXIT

image_size=$(stat -c %s -- "$image_path")
image_signature=$(od -An -tx1 -N8 -- "$image_path")
image_signature=${image_signature//[[:space:]]/}

if [[ $image_signature == 89504e470d0a1a0a && $image_size -le 2000000 ]]; then
    printf 'data:image/png;base64,'
    base64 -w 0 -- "$image_path"
    printf '\n'
fi
