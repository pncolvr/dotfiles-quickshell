#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-recent-files-test.XXXXXX)
test_entry="$test_dir/shell.qml"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/data" "$test_dir/cache"
# Folder preferences use the real repository against a private shell database.
tar -C "$project_root" --exclude='*.env' --exclude='hosts.json' -cf - src | tar -C "$test_dir" -xf -
bash "$project_root/tests/files/recent-files-helper.sh"
bash "$project_root/tests/files/folder-files-helper.sh"
bash "$project_root/tests/files/pinned-files-helper.sh"
export RECENT_FILES_TEST_FOLDER="$test_dir/folder one"
export RECENT_FILES_TEST_SECOND_FOLDER="$test_dir/folder two"
mkdir "$RECENT_FILES_TEST_FOLDER" "$RECENT_FILES_TEST_SECOND_FOLDER"
mkdir -p "$RECENT_FILES_TEST_FOLDER/subfolder/nested"
printf 'nested file' > "$RECENT_FILES_TEST_FOLDER/subfolder/nested/leaf.txt"
printf 'folder file' > "$RECENT_FILES_TEST_FOLDER/subfolder/inside.txt"
folder_stamp=$(($(date +%s) + 100))
for ((index=0; index<25; index++)); do
    printf -v name 'item%02d.txt' "$index"
    printf 'file contents' > "$RECENT_FILES_TEST_FOLDER/$name"
    touch -m -d "@$((folder_stamp + index))" "$RECENT_FILES_TEST_FOLDER/$name"
done
printf 'second folder file' > "$RECENT_FILES_TEST_SECOND_FOLDER/second.txt"
ln -s "$RECENT_FILES_TEST_FOLDER" "$test_dir/folder alias"
export RECENT_FILES_TEST_FOLDER_ALIAS="$test_dir/folder alias"
export RECENT_FILES_TEST_FILE="$test_dir/data/a recent file #1.txt"
export RECENT_FILES_TEST_PINNED_FILE="$RECENT_FILES_TEST_FOLDER/item23.txt"
printf 'File contents supplied by the drag URI.' > "$RECENT_FILES_TEST_FILE"
uri=$(jq -nr --arg path "$RECENT_FILES_TEST_FILE" '$path | split("/") | map(@uri) | join("/") | "file://" + .')
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$test_dir/data/recently-used.xbel" <<XML
<?xml version="1.0"?><xbel version="1.0"
xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
<bookmark href="$uri" added="$now" modified="$now" visited="$now">
<info><metadata owner="http://freedesktop.org"><mime:mime-type type="text/plain"/>
<bookmark:applications><bookmark:application name="Test" exec="test %u" modified="$now" count="1"/></bookmark:applications>
</metadata></info></bookmark></xbel>
XML
for test in recent-files-module-smoke recent-files-smoke recent-selection-smoke recent-folders-seed recent-navigation-smoke recent-folders-restart recent-folders-empty recent-pins-drop-smoke recent-pins-order-seed recent-pins-order-restart recent-pins-seed recent-pins-recent-default recent-pins-restart recent-pins-empty; do
    fixture=$test
    if [[ $test == recent-folders-* ]]; then
        fixture=recent-folders-smoke
        export RECENT_FOLDERS_TEST_PHASE=${test#recent-folders-}
    fi
    if [[ $test == recent-pins-order-* ]]; then
        fixture=recent-pins-order-smoke
        export RECENT_PINS_ORDER_TEST_PHASE=${test#recent-pins-order-}
    elif [[ $test == recent-pins-* && $test != recent-pins-drop-smoke ]]; then
        fixture=recent-pins-smoke
        export RECENT_PINS_TEST_PHASE=${test#recent-pins-}
        if [[ $RECENT_PINS_TEST_PHASE == restart ]]; then
            printf '%s\n' '<?xml version="1.0"?><xbel version="1.0"/>' > "$test_dir/data/recently-used.xbel"
        fi
    fi
    # Load as a root entrypoint so Quickshell scans imports just as it does for
    # shell.qml. Keep imports within that root and isolate runtime/history data.
    sed 's@"../../src@"src@g' "$project_root/tests/files/$fixture.qml" > "$test_entry"
    output=$(QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_dir/runtime" \
        XDG_DATA_HOME="$test_dir/data" XDG_CACHE_HOME="$test_dir/cache" \
        timeout -k 2 10 qs -p "$test_entry" 2>&1) || {
        printf '%s\n' "$output" >&2
        exit 1
    }
    printf '%s\n' "$output"
    [[ $output == *'PASS: recent-file '* && $output != *'RECENT FILES FAIL:'* \
        && $output != *'Failed to load configuration'* && $output != *'Binding loop detected'* \
        && $output != *'TypeError:'* && $output != *'ReferenceError:'* ]]
done
[[ -f "$RECENT_FILES_TEST_FOLDER/item24.txt" && -f "$RECENT_FILES_TEST_SECOND_FOLDER/second.txt" ]]
