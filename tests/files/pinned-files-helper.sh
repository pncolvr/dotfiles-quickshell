#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$project_root/src/services/files/pinned-files.sh"
test_dir=$(mktemp -d /tmp/quickshell-pinned-files-test.XXXXXX)
trap 'chmod -R u+rwX "$test_dir"; rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/docs"
path="$test_dir/docs/"$'résumé #1\t\n.txt\n'
printf 'contents' > "$path"
chmod 000 "$path"
ln -s "$path" "$test_dir/link.txt"
ln -s "$test_dir/deleted.txt" "$test_dir/broken.txt"
jq -n --arg path "$path" --arg directory "$test_dir" '[
    {path:$path,uri:"existing"},
    {path:($directory + "/link.txt"),uri:"symlink"},
    {path:($directory + "/missing #1.txt"),uri:"missing"},
    {path:($directory + "/removed folder/nested/file.txt"),uri:"removed-folder"},
    {path:($directory + "/broken.txt"),uri:"broken-symlink"}
]' > "$test_dir/pins.json"
result=$(bash "$helper" < "$test_dir/pins.json")
jq -e '. == ["missing","removed-folder","broken-symlink"]' <<< "$result" >/dev/null
rm -- "$path"
result=$(bash "$helper" < "$test_dir/pins.json")
jq -e '. == ["existing","symlink","missing","removed-folder","broken-symlink"]' <<< "$result" >/dev/null
[[ $(printf '[]' | bash "$helper") == '[]' ]]
mkdir "$test_dir/inaccessible"
printf 'contents' > "$test_dir/inaccessible/file.txt"
ln -s "$test_dir/inaccessible/file.txt" "$test_dir/inaccessible-link.txt"
chmod 000 "$test_dir/inaccessible"
if [[ ! -x $test_dir/inaccessible ]]; then
    result=$(jq -n --arg directory "$test_dir" '[
        {path:($directory + "/inaccessible/file.txt"),uri:"inaccessible"},
        {path:($directory + "/inaccessible/deleted.txt"),uri:"unknown"},
        {path:($directory + "/inaccessible-link.txt"),uri:"inaccessible-link"}
    ]' | bash "$helper")
    [[ $result == '[]' ]]
fi
for input in '{}' '[{"path":"relative","uri":"bad"}]' '[{"path":"/bad\u0000path","uri":"bad"}]' '[{"path":"/file","uri":"bad\u0000uri"}]' 'not json'; do
    if printf '%s' "$input" | bash "$helper" > "$test_dir/output" 2> "$test_dir/error"; then
        printf 'Invalid pins accepted: %s\n' "$input" >&2; exit 1
    fi
    [[ ! -s $test_dir/output ]]
done
printf 'PASS: pinned-file existence, unreadable documents, symlinks, deleted folders, escaped names and invalid input\n'
