#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$project_root/src/services/files/recent-files.sh"
test_dir=$(mktemp -d /tmp/quickshell-recent-files-helper.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
source_path="$test_dir/recently-used.xbel"
now=$(date +%s)

uri_for() { jq -nr --arg path "$1" '$path | split("/") | map(@uri) | join("/") | "file://" + .'; }
start_store() {
    printf '%s\n' '<xbel version="1.0" xmlns:b="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:m="http://www.freedesktop.org/standards/shared-mime-info">' > "$source_path"
}
add_bookmark() {
    local uri stamp private mime
    uri=$(jq -nr --arg uri "$1" '$uri | @html')
    stamp=$(date -u -d "@$((now - $2 * 86400))" +%Y-%m-%dT%H:%M:%SZ)
    private=''
    if [[ ${3:-false} == true ]]; then private='<b:private/>'; fi
    mime=${4:-text/plain}
    printf '<bookmark href="%s" modified="%s" visited="%s" added="%s"><info><metadata owner="http://freedesktop.org"><m:mime-type type="%s"/>%s</metadata></info></bookmark>\n' \
        "$uri" "$stamp" "$stamp" "$stamp" "$mime" "$private" >> "$source_path"
}
end_store() { printf '</xbel>\n' >> "$source_path"; }
read_files() { bash "$helper" --source "$source_path" "$@"; }
check() {
    if ! jq -e "$@" <<< "$result" >/dev/null; then
        printf 'FAIL: recent-file helper assertion: %s\n%s\n' "$*" "$result" >&2
        exit 1
    fi
}
expect_error() {
    local expected=$1 status=0
    shift
    result=$(read_files "$@") || status=$?
    [[ $status == "$expected" ]] || { printf 'Expected exit %s, got %s\n' "$expected" "$status" >&2; exit 1; }
    check '.files == [] and (.error | length > 0)'
}

# Missing history is a normal empty state.
result=$(read_files)
check '.files == [] and .error == ""'

for name in old.txt new.txt middle.txt private.txt; do printf 'file contents' > "$test_dir/$name"; done
good_uri=$(uri_for "$test_dir/new.txt")
start_store
add_bookmark "$(uri_for "$test_dir/old.txt")" 10
add_bookmark "$good_uri" 0 false application/pdf
add_bookmark "$(uri_for "$test_dir/middle.txt")" 2
add_bookmark "$(uri_for "$test_dir/private.txt")" 0 true
add_bookmark "$(uri_for "$test_dir/gone.txt")" 0
add_bookmark "$(uri_for "$test_dir")" 0
add_bookmark 'https://example.com/document' 0
add_bookmark "file://other-host${good_uri#file://}" 0
add_bookmark "file://localhost${good_uri#file://}" 2
add_bookmark "${good_uri}%00" 0
add_bookmark "${good_uri}%oops" 0
end_store
result=$(read_files)
check '[.files[].name] == ["new.txt", "middle.txt"] and .files[0].icon == "application-pdf"'
result=$(read_files --max-items 1)
check '[.files[].name] == ["new.txt"]'
result=$(read_files --max-days 0 --max-items 0)
check '[.files[].name] == ["new.txt", "middle.txt", "old.txt"]'
result=$(read_files --max-items 0 --max-days 1)
check '[.files[].name] == ["new.txt"]'
result=$(read_files --max-items 01)
check '.files | length == 1'

start_store
for name in 'Track 10.wav' 'Track 2.wav' 'Track 1.wav'; do
    printf 'audio contents' > "$test_dir/$name"
    add_bookmark "$(uri_for "$test_dir/$name")" 0
done
end_store
result=$(read_files --max-items 2)
check '[.files[].name] == ["Track 1.wav", "Track 2.wav"]'

# Escaped names and namespace aliases survive XML, Bash, JSON and file URI conversion.
name=$'résumé #1 & <notes>\t\n.txt\n'
path="$test_dir/$name"
printf 'actual file content' > "$path"
uri=$(uri_for "$path")
start_store
add_bookmark "$uri" 0
end_store
before=$(sha256sum "$source_path")
stamp=$(stat -c %Y "$source_path")
result=$(read_files)
check --arg path "$path" --arg uri "$uri" --arg name "$name" --argjson used "$((now * 1000))" \
    '.files | length == 1 and .[0].path == $path and .[0].uri == $uri and .[0].name == $name and .[0].usedAt == $used'
[[ $(sha256sum "$source_path") == "$before" && $(stat -c %Y "$source_path") == "$stamp" ]]

# Absent attributes must not shift the remaining tab-delimited fields.
stamp=$(date -u -d "@$now" +%Y-%m-%dT%H:%M:%SZ)
start_store
printf '<bookmark href="%s" visited="%s"/>\n' "$good_uri" "$stamp" >> "$source_path"
end_store
result=$(read_files)
check --argjson used "$((now * 1000))" '.files[0].name == "new.txt" and .files[0].usedAt == $used'

printf 'not XML' > "$source_path"
expect_error 1
printf '<different-root/>' > "$source_path"
expect_error 1
printf '<!DOCTYPE xbel [<!ENTITY file SYSTEM "file:///etc/passwd">]><xbel/>' > "$source_path"
expect_error 1
expect_error 2 --max-days -1
expect_error 2 --max-items nonsense
expect_error 2 --max-items 2147483648
expect_error 2 --max-days
expect_error 2 --unknown

bash_bin=$(command -v bash)
mkdir "$test_dir/no-dependencies"
status=0
result=$(PATH="$test_dir/no-dependencies" "$bash_bin" "$helper") || status=$?
[[ $status == 1 ]]
check '.error | contains("xsltproc")'
printf 'PASS: Bash recent-file helper, limits, filtering, natural order, URI escaping, unchanged history and error states\n'
