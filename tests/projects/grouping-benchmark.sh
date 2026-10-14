#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source_repo=${PROJECT_GROUPING_BASELINE_REPO:-$root_dir}
baseline=${PROJECT_GROUPING_BASELINE:-HEAD}
count=${PROJECT_GROUPING_BENCH_COUNT:-2000}
[[ $count =~ ^[1-9][0-9]*$ && $count -le 10000 ]]
fixture=$(mktemp -d /tmp/quickshell-grouping-bench.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir "$fixture/bin"
printf '#!/usr/bin/env bash\nprintf "[]\\n"\n' > "$fixture/bin/hyprctl"
chmod +x "$fixture/bin/hyprctl"
tar -C "$root_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
git -C "$source_repo" show "$baseline:src/services/storage/ProjectRepository.qml" > "$fixture/baseline.qml"
sed 's@"../../src@"src@g' "$root_dir/tests/projects/grouping-benchmark.qml" > "$fixture/shell.qml"
for phase in baseline grouped; do
    if [[ $phase == baseline ]]; then cp "$fixture/baseline.qml" "$fixture/src/services/storage/ProjectRepository.qml";
    else cp "$root_dir/src/services/storage/ProjectRepository.qml" "$fixture/src/services/storage/ProjectRepository.qml"; fi
    PATH="$fixture/bin:$PATH" PROJECT_GROUPING_BENCH_COUNT="$count" PROJECT_GROUPING_BENCH_PHASE="$phase" \
        QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
        timeout 60 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    rg 'GROUPING BENCH |PASS:' "$fixture/log"
    if ! rg -q 'PASS: project reload' "$fixture/log" || rg -q 'GROUPING BENCH FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
done
