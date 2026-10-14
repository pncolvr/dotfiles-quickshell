#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../rbw/common.sh"
manager_test_root=$project_root/tests/security/rbw-manager
export RBW_TEST_ROOT=$test_dir
export PATH=$test_dir/bin:$PATH
cp "$manager_test_root/mock-rbw.sh" "$test_dir/bin/rbw"
chmod +x "$test_dir/bin/rbw"
mkdir -m 700 "$XDG_CACHE_HOME/rbw"
item_id=11111111-1111-1111-1111-111111111111
printf '%s\n' '{"entries":[{"id":"11111111-1111-1111-1111-111111111111","master_password_reprompt":0}]}' > "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
printf '%s\n' '[{"id":"11111111-1111-1111-1111-111111111111","name":"Example login","user":"sample-user","folder":"Work","uris":["https://example.test"],"type":"Login"},{"id":"22222222-2222-2222-2222-222222222222","name":"Other note","folder":"Personal","type":"Note"}]' > "$test_dir/entries.json"
printf '%s\n' '{"id":"11111111-1111-1111-1111-111111111111","name":"Example login","folder":"Work","data":{"username":"sample-user","password":"SYNTHETIC_SECRET_DO_NOT_LOG","totp":"SYNTHETIC_SEED","uris":[{"uri":"https://example.test","match_type":"Domain"}]},"notes":"Original notes","fields":[],"history":[{"password":"SYNTHETIC_HISTORY"}]}' > "$test_dir/entry.json"
