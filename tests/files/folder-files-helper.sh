#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$project_root/src/services/files/folder-files.sh"
test_dir=$(mktemp -d /tmp/quickshell-folder-files-test.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
folder="$test_dir/folder with spaces"
now=$(date +%s)
mkdir -p "$folder/subfolder"
for ((index=0; index<25; index++)); do
    printf -v name 'item%02d.txt' "$index"
    printf 'contents' > "$folder/$name"
    touch -m -d "@$((now + 100 + index))" "$folder/$name"
done
printf 'nested' > "$folder/subfolder/hidden-from-list.txt"
ln -s "$test_dir/missing.txt" "$folder/broken-link.txt"
result=$(bash "$helper" --folder "$folder")
jq -e --arg folder "$folder" --argjson newest "$(((now + 124) * 1000))" '.error == "" and .folder == $folder and (.files | length == 26)
    and .files[0].name == "subfolder" and .files[0].isDirectory
    and .files[1].name == "item24.txt" and .files[25].name == "item00.txt"
    and .files[1].timeKind == "modified" and .files[1].usedAt == $newest
    and .files[1].isDirectory == false
    and (.files | any(.name == "subfolder" and .isDirectory and .icon == "inode-directory"))
    and (.files | all(.name != "hidden-from-list.txt" and .name != "broken-link.txt"))' <<< "$result" >/dev/null
result=$(bash "$helper" --folder "$folder/subfolder")
jq -e '(.files | length == 1) and .files[0].name == "hidden-from-list.txt"' <<< "$result" >/dev/null

special_folder="$test_dir/special"
mkdir "$special_folder"
name=$'résumé #1 & <notes>\t\n.txt\n'
path="$special_folder/$name"
printf 'file' > "$path"
result=$(bash "$helper" --folder "$special_folder")
uri=$(jq -nr --arg path "$path" '$path | split("/") | map(@uri) | join("/") | "file://" + .')
jq -e --arg path "$path" --arg uri "$uri" '.files[0].path == $path and .files[0].uri == $uri' <<< "$result" >/dev/null
ln -s "$special_folder" "$test_dir/alias"
result=$(bash "$helper" --folder "$test_dir/alias")
jq -e --arg folder "$special_folder" '.folder == $folder' <<< "$result" >/dev/null
result=$(HOME="$test_dir" bash "$helper" --folder '~/special')
jq -e --arg folder "$special_folder" '.folder == $folder' <<< "$result" >/dev/null

# Drops reuse the same metadata, preserve unusual names, resolve folder aliases,
# and ignore duplicates, directories and unavailable files without opening them.
result=$(jq -n --arg path "$path" --arg alias "$test_dir/alias/$name" --arg folder "$folder" \
    '[$path, $alias, ($folder + "/item01.txt"), $folder, ($folder + "/missing.txt")]' | bash "$helper" --files)
jq -e --arg path "$path" --arg uri "$uri" --arg folder "$special_folder" \
    '(.files | length) == 2 and (.files | all(.isDirectory == false))
    and (.files | any(.path == $path and .uri == $uri and .directory == $folder))' <<< "$result" >/dev/null
result=$(printf '[]' | bash "$helper" --files)
jq -e '.files == [] and .error == ""' <<< "$result" >/dev/null
for input in '{}' '["relative.txt"]' '["/tmp/a\u0000b"]' '[false]' 'not json'; do
    result=$(printf '%s' "$input" | bash "$helper" --files) && exit 1
    jq -e '.files == [] and (.error | length > 0)' <<< "$result" >/dev/null
done

# Reproducible creation times, including a filesystem with no birth timestamp.
sort_folder="$test_dir/sorting"
mkdir "$sort_folder" "$test_dir/bin"
mkdir "$sort_folder/Folder1" "$sort_folder/Folder2" "$sort_folder/Folder10" "$sort_folder/FolderNew"
for name in created-old.txt created-new.txt unknown.txt; do printf 'file' > "$sort_folder/$name"; done
real_stat=$(command -v stat)
cat > "$test_dir/bin/stat" <<SCRIPT
#!/bin/bash
case "\${!#}" in
    */FolderNew) printf '200 0' ;;
    */Folder1|*/Folder2|*/Folder10) printf '100 0' ;;
    */created-old.txt) printf '500 100' ;;
    */created-new.txt) printf '400 600' ;;
    */unknown.txt) printf '300 0' ;;
    *) exec "$real_stat" "\$@" ;;
esac
SCRIPT
chmod +x "$test_dir/bin/stat"
result=$(PATH="$test_dir/bin:$PATH" bash "$helper" --folder "$sort_folder")
jq -e '[.files[].name] == ["FolderNew", "Folder1", "Folder2", "Folder10", "created-new.txt", "created-old.txt", "unknown.txt"]
    and (.files[:4] | all(.isDirectory)) and (.files[4:] | all(.isDirectory == false))
    and .files[4].timeKind == "created" and .files[6].timeKind == "modified"
    and .files[4].usedAt == 600000' <<< "$result" >/dev/null

# Natural filename ties apply across the full folder list.
tracks="$test_dir/tracks"
mkdir "$tracks"
for ((track=23; track>=1; track--)); do
    printf 'audio contents' > "$tracks/Track $track.wav"
    touch -m -d "@$((now + 200))" "$tracks/Track $track.wav"
done
result=$(bash "$helper" --folder "$tracks")
jq -e '(.files | length) == 23 and .files[0].name == "Track 1.wav"
    and .files[1].name == "Track 2.wav" and .files[9].name == "Track 10.wav"
    and .files[22].name == "Track 23.wav"' <<< "$result" >/dev/null
touch -m -d "@$((now + 201))" "$tracks/Track 23.wav"
result=$(bash "$helper" --folder "$tracks")
jq -e '.files[0].name == "Track 23.wav" and .files[1].name == "Track 1.wav"' <<< "$result" >/dev/null

for bad in missing-file invalid-option missing-value; do
    status=0
    case "$bad" in
        missing-file) result=$(bash "$helper" --folder "$test_dir/missing") || status=$?; expected=1 ;;
        invalid-option) result=$(bash "$helper" --unknown) || status=$?; expected=2 ;;
        missing-value) result=$(bash "$helper" --folder) || status=$?; expected=2 ;;
    esac
    [[ $status == "$expected" ]]
    jq -e '.files == [] and (.error | length > 0)' <<< "$result" >/dev/null
done
printf 'PASS: unlimited folder files, directories, recency and natural order, missing creation time, aliases, escaping and invalid folders\n'
