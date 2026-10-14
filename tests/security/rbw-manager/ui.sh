#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
copy_shell
printf '%s\n' '{"id":"22222222-2222-2222-2222-222222222222","name":"Other note","folder":"Personal","data":null,"notes":"Synthetic note content","fields":[],"history":[]}' > "$test_dir/note.json"
printf '%s\n' '{"id":"33333333-3333-3333-3333-333333333333","name":"Zebra login","folder":"Personal","data":{"username":"zebra-user","password":"SYNTHETIC_SECOND_SECRET"},"notes":"","fields":[],"history":[]}' > "$test_dir/second-login.json"
jq '. += [{"id":"33333333-3333-3333-3333-333333333333","name":"Zebra login","user":"zebra-user","folder":"Personal","uris":[],"type":"Login"}]' "$test_dir/entries.json" > "$test_dir/entries-next"
mv "$test_dir/entries-next" "$test_dir/entries.json"
jq '.entries += [{"id":"22222222-2222-2222-2222-222222222222","master_password_reprompt":0},{"id":"33333333-3333-3333-3333-333333333333","master_password_reprompt":0}]' "$XDG_CACHE_HOME/rbw/default:user@example.test.json" > "$test_dir/cache-next"
mv "$test_dir/cache-next" "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
sed 's@"../../../src@"src@g' "$manager_test_root/manager.qml" > "$test_dir/shell.qml"
cat > "$test_dir/bin/wl-copy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
jq -nc '$ARGS.positional' --args -- "$@" > "$RBW_TEST_ROOT/copy-args"
cat > "$RBW_TEST_ROOT/copied"
# Behave like the foreground owner. No real clipboard access.
exec sleep 60
MOCK
chmod +x "$test_dir/bin/wl-copy"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
qs -p "$test_dir" > "$test_dir/log" 2>&1 & shell_pid=$!
wait_state '.visible==false'
ipc open
wait_state '.visible and (.busy|not) and .count==3 and .rows==2 and .typeFilter=="Login" and .details and .selectedFirst and .comboFramed and .filterGap==.filterSpacing and .listBottomAligned and .hintsVisible and (.statusVisible|not) and .addVisible and .addEnabled and .addBesideLock'
ipc toggleType
wait_state '.typeExpanded and .typeChoiceReady'
timeout 4 qs ipc -p "$test_dir" call rbwtest chooseType Note
wait_state '(.busy|not) and .rows==1 and .typeFilter=="Note" and .noteSelected and .selectedFirst'
ipc toggleType
wait_state '.typeExpanded and .typeChoiceReady'
timeout 4 qs ipc -p "$test_dir" call rbwtest chooseType Login
wait_state '(.busy|not) and .rows==2 and .typeFilter=="Login" and (.noteSelected|not) and .selectedFirst'
ipc toggleFolder
wait_state '.folderExpanded and .folderChoiceReady'
ipc chooseWork
wait_state '(.folderExpanded|not) and .rows==1 and .filterGap==.filterSpacing'
ipc toggleFolder
wait_state '.folderExpanded and .folderChoiceReady'
ipc chooseAll
wait_state '(.folderExpanded|not) and .rows==2 and .filterGap==.filterSpacing'
ipc search
wait_state '.rows==1'
ipc resetSearch
wait_state '.rows==2 and .rowReady and (.busy|not) and .selectionMatches'
ipc moveDown
wait_state '(.busy|not) and .selectionMatches and .detailId=="33333333-3333-3333-3333-333333333333"'
ipc moveUp
wait_state '(.busy|not) and .selectionMatches and .selectedFirst'
ipc searchSecond
wait_state '(.busy|not) and .rows==1 and .selectionMatches and .detailId=="33333333-3333-3333-3333-333333333333"'
ipc resetSearch
wait_state '(.busy|not) and .rows==2 and .selectionMatches and .selectedFirst'
# Rapid typing keeps only the latest selection; an empty result cancels a pending detail read.
detail_layout=$(snapshot | jq -c '[.detailScrollHeight,.detailActionsVisible]')
ipc revealDetail
wait_state '(.detailMasked|not)'
touch "$test_dir/slow"
ipc searchSecond
wait_state '.busy and .details and .detailId=="11111111-1111-1111-1111-111111111111" and .detailMasked and (.detailEnabled|not) and (.detailActionsEnabled|not) and .listEnabled'
[[ $(snapshot | jq -c '[.detailScrollHeight,.detailActionsVisible]') == "$detail_layout" ]]
ipc resetSearch
wait_state '(.busy|not) and .selectionMatches and .selectedFirst'
[[ $(snapshot | jq -c '[.detailScrollHeight,.detailActionsVisible]') == "$detail_layout" ]]
ipc searchSecond
wait_state '.busy'
ipc searchMissing
wait_state '(.busy|not) and .rows==0 and (.details|not)'
rm "$test_dir/slow"
ipc resetSearch
wait_state '(.busy|not) and .rows==2 and .selectionMatches and .selectedFirst'
touch "$test_dir/fail"
ipc searchSecond
wait_state '(.busy|not) and .hasError and (.details|not)'
rm "$test_dir/fail"
ipc resetSearch
wait_state '(.busy|not) and .selectionMatches and .selectedFirst'
ipc clickEntry
wait_state '.details and (.busy|not)'
# A delayed background lock check keeps the selected details, controls and layout stable.
layout_before=$(snapshot | jq -c '[.statusHeight,.listHeight]')
touch "$test_dir/slow-poll"
ipc poll
wait_state '.checking and (.busy|not) and .details and .listEnabled'
[[ $(snapshot | jq -c '[.statusHeight,.listHeight]') == "$layout_before" ]]
wait_state '(.checking|not) and (.busy|not) and .details and .listEnabled'
[[ $(snapshot | jq -c '[.statusHeight,.listHeight]') == "$layout_before" ]]
rm "$test_dir/slow-poll"
ipc edit
wait_state '.editing and .masked and (.draftEmpty|not) and .formActionsRight and .hintsBelowActions and .notesMaskClean and .addVisible and (.addEnabled|not)'
if [[ -n ${RBW_STYLE_PREVIEW_OUTPUT:-} ]]; then
    ipc preview
    for ((i=0;i<100;i++)); do [[ -s $test_dir/form.png ]] && break; sleep 0.02; done
    cp -- "$test_dir/form.png" "$RBW_STYLE_PREVIEW_OUTPUT"
fi
ipc eye
wait_state '(.masked|not)'
ipc generate
wait_state '.editing and (.busy|not) and (.masked|not)'
ipc notesEye
wait_state '.notesRevealed and .notesEditable'
ipc notesEye
wait_state '(.notesRevealed|not) and (.notesEditable|not) and .notesMaskClean'
ipc cancel
wait_state '(.editing|not) and .draftEmpty and .masked'
ipc newLogin
wait_state '.editing and .adding and .masked and .addVisible and (.addEnabled|not)'
ipc typeDraft
ipc generate
wait_state '.editing and (.busy|not) and .masked'
ipc save
wait_state '(.busy|not) and (.editing|not) and .draftEmpty and .selectedFirst'
rg -q '^SYNTHETIC_GENERATED_PASSWORD$' "$test_dir/write-input"
ipc copy
wait_state '.copying'
for ((i=0;i<100;i++)); do [[ -f $test_dir/copied ]] && break; sleep 0.02; done
[[ $(<"$test_dir/copied") == SYNTHETIC_COPY_PASSWORD ]]
jq -e '. == ["--foreground","--sensitive","--type","text/plain;charset=utf-8"]' "$test_dir/copy-args" >/dev/null
ipc expireCopy
wait_state '(.copying|not)'
ipc select
wait_state '.details and (.busy|not)'
ipc deleteEntry
wait_state '.deleting'
ipc back
wait_state '(.deleting|not)'
! jq -se 'any(.[]; .[0]=="remove")' "$test_dir/calls" >/dev/null
ipc deleteEntry; ipc confirmDelete
wait_state '(.busy|not) and .details and .selectedFirst'
jq -se 'any(.[]; .==["remove","11111111-1111-1111-1111-111111111111"])' "$test_dir/calls" >/dev/null
# Superseded responses cannot restore entry details after closing or locking.
touch "$test_dir/slow"
ipc select; ipc close
wait_state '(.busy|not) and (.visible|not) and (.details|not) and .draftEmpty'
rm "$test_dir/slow"
ipc open
wait_state '.visible and (.busy|not) and .count==3'
# A lock discovered during a foreground read invalidates the late detail reply
# without automatically reopening/unlocking the vault.
touch "$test_dir/slow-poll" "$test_dir/slow"
ipc poll
wait_state '.checking and (.busy|not)'
ipc select
wait_state '.busy and .statusVisible and (.hintsVisible|not) and .statusBelowActions and .statusRight'
touch "$test_dir/locked"
wait_state '(.checking|not) and (.busy|not) and (.details|not) and .count==0 and .hasError'
rm "$test_dir/slow-poll" "$test_dir/slow"
ipc lock
wait_state '(.busy|not) and (.details|not) and .count==0 and .hasError and .statusVisible and (.hintsVisible|not) and .statusBelowActions and .statusRight'
# An empty vault has no selected entry and does not request nonexistent details.
ipc close
printf '[]\n' > "$test_dir/entries.json"
ipc open
wait_state '.visible and (.busy|not) and .count==0 and (.details|not)'
! rg -q 'SYNTHETIC_(SECRET|DRAFT|GENERATED|COPY|SEED|HISTORY)|TypeError|ReferenceError|Error:|Binding loop|Cannot assign' "$test_dir/log"
printf 'PASS: framed dropdowns, folder filtering, compact results spacing, first entry selected on load, single-click details, stable entry transitions and background polling, search and arrow selection, rapid typing and empty results, private host, drafts, masking, writes, copy lifetime, deletion, lock and stale replies\n'
