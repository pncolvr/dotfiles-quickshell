#!/usr/bin/env bash
set -euo pipefail
script=${STATUS_DETECTION_SCRIPT:-${ZDOTDIR:-$HOME/.config/zsh}/scripts/status/detection.sh}
manager=${STATUS_MANAGER_SCRIPT:-${ZDOTDIR:-$HOME/.config/zsh}/scripts/status/manager.sh}
test_dir=$(mktemp -d /tmp/quickshell-status-detection.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/zsh/scripts/status"
export STATUS_DETECTION_WORK="$test_dir/work [x]" STATUS_DETECTION_STATE="$test_dir/state"
export STATUS_DETECTION_LOG="$test_dir/log" STATUS_DETECTION_CASE=matches
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
[[ $STATUS_DETECTION_CASE != failure ]] || exit 2
[[ $STATUS_DETECTION_CASE != none ]] || exit 1
printf 'p100\0cdotnet\0\nfcwd\0n%s/gaia\0\nf3\0n%s/gaia/file "quoted"\0\nf4\0n%s/gaia/file "quoted"\0\n' "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK"
printf 'p200\0cdotnet\0\nfcwd\0n%s/hera\0\nf5\0n%s/hera/newline\nfile\0\n' "$STATUS_DETECTION_WORK" "$STATUS_DETECTION_WORK"
printf 'p300\0cignored\0\nfcwd\0n%s-other/project\0\n' "$STATUS_DETECTION_WORK"
MOCK
chmod +x "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH" XDG_RUNTIME_DIR="$test_dir"
output=$(bash "$script" "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_WORK" teams-for-linux other)
bash "$script" --has-work-files "$STATUS_DETECTION_WORK"
jq -e --arg base "$STATUS_DETECTION_WORK" '
    .source=="automatic" and .automaticStatus=="work" and .errors==[] and (.matches|length)==2
    and (.matches[]|select(.name=="dotnet")|.methods==["directory","file"] and (.paths|length)==4
        and (.paths|index($base+"/gaia/file \"quoted\""))!=null and (.paths|index($base+"/hera/newline\nfile"))!=null)
    and (.matches[]|select(.name=="teams-for-linux")|.methods==["process"] and .paths==["/opt/Teams for Linux/teams-for-linux"])
' <<< "$output" >/dev/null
printf personal > "$STATUS_DETECTION_STATE"
output=$(bash "$script" "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_WORK" teams-for-linux)
jq -e '.source=="manual" and .automaticStatus=="work" and (.matches|length)==2' <<< "$output" >/dev/null
STATUS_DETECTION_CASE=none bash "$script" "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_WORK" teams-for-linux | jq -e '.matches==[] and .errors==[] and .automaticStatus=="personal"' >/dev/null
if STATUS_DETECTION_CASE=none bash "$script" --has-work-files "$STATUS_DETECTION_WORK"; then exit 1; fi
STATUS_DETECTION_CASE=failure bash "$script" "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_WORK" teams-for-linux | jq -e '.matches==[] and (.errors|length)==2' >/dev/null
cp "$script" "$test_dir/zsh/scripts/status/detection.sh"
cp "$manager" "$test_dir/zsh/scripts/status/manager.sh"
cat > "$test_dir/zsh/scripts/_common.sh" <<'COMMON'
get_env_file() { printf '%s/manager.env\n' "${1%/*}"; }
COMMON
cat > "$test_dir/zsh/scripts/status/manager.env" <<'ENV'
STATE_FILE="$STATUS_DETECTION_STATE"
LOG_FILE="$STATUS_DETECTION_LOG"
WORK_BASE_DIRECTORY="$STATUS_DETECTION_WORK"
WORKING_PROCESSES=(teams-for-linux)
ENV
printf 'unchanged\n' > "$STATUS_DETECTION_LOG"
before=$(sha256sum "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_LOG")
ZDOTDIR="$test_dir/zsh" bash "$test_dir/zsh/scripts/status/manager.sh" --explain | jq -e '.source=="manual" and (.matches|length)==2' >/dev/null
[[ $(sha256sum "$STATUS_DETECTION_STATE" "$STATUS_DETECTION_LOG") == "$before" ]]
printf 'PASS: automatic detection, distinct processes/paths, literal directory boundaries, JSON escaping, errors and read-only manager report\n'
