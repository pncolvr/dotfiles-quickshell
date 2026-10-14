#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-fts-bench.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/data"
ln -s "$root_dir/src" "$fixture/src"
sed 's@"../../../src@"src@g' "$root_dir/tests/clipboard/fts/benchmark.qml" > "$fixture/shell.qml"
XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    QT_QPA_PLATFORM=offscreen timeout 60 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
rg 'BENCH|PASS:' "$fixture/log"
! rg -q 'Local database operation failed|Local database failure:|TypeError:|ReferenceError:' "$fixture/log"
start_ms=$(date +%s%3N)
jq -nc '{engine:"indexed",query:"alpha",kind:"",pinned:false,limit:51,offset:0}' |
    bash "$root_dir/src/services/clipboard/query.sh" "$fixture/data/quickshell.db" | jq -e '.error=="" and (.rows|length)==51' >/dev/null
printf 'BENCH pipeline query_ms=%s database_bytes=%s\n' "$(( $(date +%s%3N) - start_ms ))" "$(stat -c %s "$fixture/data/quickshell.db")"
