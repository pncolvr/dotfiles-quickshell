#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-image-encoding.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT

printf '\211PNG\r\n\032\npayload' > "$test_dir/valid image.png"
expected="data:image/png;base64,$(base64 -w 0 -- "$test_dir/valid image.png")"
[[ $(bash "$project_root/src/services/notifications/encode-image.sh" "$test_dir/valid image.png") == "$expected" ]]
[[ ! -e "$test_dir/valid image.png" ]]

printf 'not a PNG' > "$test_dir/invalid.png"
[[ -z $(bash "$project_root/src/services/notifications/encode-image.sh" "$test_dir/invalid.png") ]]
[[ ! -e "$test_dir/invalid.png" ]]

printf '\211PNG\r\n\032\n' > "$test_dir/large.png"
truncate -s 2000001 "$test_dir/large.png"
[[ -z $(bash "$project_root/src/services/notifications/encode-image.sh" "$test_dir/large.png") ]]
[[ ! -e "$test_dir/large.png" ]]
printf 'PASS: Bash PNG signature, size limit, base64 encoding and temporary-file cleanup\n'
