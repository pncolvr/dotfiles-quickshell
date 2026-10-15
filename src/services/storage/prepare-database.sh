#!/usr/bin/env bash
# Only paths/metadata cross this boundary, never clipboard content.
set -euo pipefail
umask 077
path=${1:?}
directory=${path%/*}
mkdir -p -- "$directory"
[[ -d $directory && -O $directory && ! -L $directory ]]
chmod 700 -- "$directory"
# Roll back an interrupted restore before Qt attaches the database.
if [[ -e $directory/.restore-pending.json ]]; then
    bash "${BASH_SOURCE[0]%/*}/backup.sh" recover "$path" >/dev/null
fi
for file in "$path" "$path-journal" "$path-wal" "$path-shm"; do
    [[ ! -e $file ]] || { [[ -f $file && ! -L $file && -O $file ]] && chmod 600 -- "$file"; }
done
[[ -e $path ]] || install -m 600 /dev/null "$path"
