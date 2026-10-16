#!/usr/bin/env bash
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script="$root_dir/src/services/status/detection.sh"
test_dir=$(mktemp -d /tmp/quickshell-status-detection.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
export STATUS_DETECTION_WORK="$test_dir/work [x]"
export STATUS_DETECTION_CASE=matches
export STATUS_DETECTION_SECOND="$test_dir/second folder \"literal\""
export STATUS_DETECTION_LSOF_LOG="$test_dir/lsof-calls"
cat > "$test_dir/bin/pgrep" <<'MOCK'
#!/usr/bin/env bash
[[ $STATUS_DETECTION_CASE != failure ]] || exit 2
[[ $STATUS_DETECTION_CASE != none ]] || exit 1
[[ ${!#} == teams-for-linux ]] || exit 1
printf '10 teams-for-linux\n20 teams-for-linux\n'
MOCK
cat > "$test_dir/bin/readlink" <<'MOCK'
#!/usr/bin/env bash
printf '/opt/Teams for Linux/teams-for-linux\n'
MOCK
cat > "$test_dir/bin/lsof" <<'MOCK'
#!/usr/bin/env bash
printf 'scan\n' >> "$STATUS_DETECTION_LSOF_LOG"
[[ $STATUS_DETECTION_CASE != failure ]] || exit 2
[[ $STATUS_DETECTION_CASE != none ]] || exit 1
printf 'p100\0cdotnet\0\nfcwd\0n%s/gaia\0\nf3\0n%s/gaia/file "quoted"\0\nf4\0n%s/gaia/file "quoted"\0\n' "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK"
printf 'p200\0cdotnet\0\nfcwd\0n%s/hera\0\nf5\0n%s/hera/newline\nfile\0\n' "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK"
printf 'p300\0cignored\0\nfcwd\0n%s-other/project\0\n' "$STATUS_DETECTION_WORK"
printf 'p400\0csecond-only\0\nfcwd\0n%s/project\0\n' "$STATUS_DETECTION_SECOND"
MOCK
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH" XDG_RUNTIME_DIR="$test_dir"
rules=$(jq -nc --arg directory "$STATUS_DETECTION_WORK" --arg second "$STATUS_DETECTION_SECOND" '{workDirectories:[$directory,($directory+"/gaia"),$second],processes:["teams-for-linux","other"]}')
output=$(bash "$script" <<< "$rules")
jq -e --arg base "$STATUS_DETECTION_WORK" '
    .errors==[] and (.matches|length)==3
    and (.matches[]|select(.name=="dotnet")|.methods==["directory","file"] and (.paths|length)==4
        and (.paths|index($base+"/gaia/file \"quoted\""))!=null and (.paths|index($base+"/hera/newline\nfile"))!=null)
    and (.matches[]|select(.name=="teams-for-linux")|.methods==["process"] and .paths==["/opt/Teams for Linux/teams-for-linux"])
' <<< "$output" >/dev/null
[[ $(wc -l < "$STATUS_DETECTION_LSOF_LOG") == 1 ]]
jq -e --arg path "$STATUS_DETECTION_SECOND/project" '.matches[]|select(.name=="second-only")|.methods==["directory"] and .paths==[$path]' <<< "$output" >/dev/null
bash "$script" <<< '{"workDirectories":["/"],"processes":[]}' | jq -e '(.matches|length)==3 and any(.matches[]; .name=="ignored")' >/dev/null
before=$(wc -l < "$STATUS_DETECTION_LSOF_LOG")
bash "$script" <<< '{"workDirectories":[],"processes":[]}' | jq -e '.matches==[] and .errors==[]' >/dev/null
[[ $(wc -l < "$STATUS_DETECTION_LSOF_LOG") == "$before" ]]
STATUS_DETECTION_CASE=none bash "$script" <<< "$rules" | jq -e '.matches==[] and .errors==[]' >/dev/null
STATUS_DETECTION_CASE=failure bash "$script" <<< "$rules" | jq -e '.matches==[] and (.errors|length)==3' >/dev/null
printf 'PASS: multiple folders, one open-file scan, overlapping roots, empty/root lists, literal boundaries and partial errors\n'
