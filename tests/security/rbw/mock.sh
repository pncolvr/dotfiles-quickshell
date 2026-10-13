#!/usr/bin/env bash
# Source only after common.sh. All credentials here are synthetic fixtures.
export RBW_TEST_ROOT="$test_dir" RBW_TEST_ID=12345678-1234-4234-8234-123456789abc
export RBW_TEST_SECRET="  RBW_CREDENTIAL_MARKER_%_é_'\"  " RBW_TEST_USER=RBW_USERNAME_MARKER
printf 'ok\n' > "$test_dir/control"
mkdir -p "$XDG_CACHE_HOME/rbw" "$XDG_CONFIG_HOME/quickshell/src/services/launcher"
chmod 700 "$XDG_CACHE_HOME/rbw"
cp "$rbw_test_root/mock-rbw.sh" "$test_dir/bin/rbw"
cp "$rbw_test_root/mock-picker.sh" "$XDG_CONFIG_HOME/quickshell/src/services/launcher/launcher.sh"
chmod +x "$test_dir/bin/rbw" "$XDG_CONFIG_HOME/quickshell/src/services/launcher/launcher.sh"
export PATH="$test_dir/bin:$PATH"
reset_mock() {
    printf 'ok\n' > "$test_dir/control"
    jq -nc '{entries:[{id:env.RBW_TEST_ID,master_password_reprompt:0}]}' > "$XDG_CACHE_HOME/rbw/default:user@example.test.json"
    jq -nc '[{id:env.RBW_TEST_ID,type:"Login",name:"Same | label",user:"account",uris:[env.RBW_TEST_URL]}]' > "$test_dir/entries.json"
    jq -nc '{id:env.RBW_TEST_ID,data:{username:env.RBW_TEST_USER,password:env.RBW_TEST_SECRET,
        totp:"NEVER_TRANSFER_SEED",uris:[{uri:env.RBW_TEST_URL,match_type:1}]},
        history:[{password:"NEVER_TRANSFER_HISTORY"}]}' > "$test_dir/entry.json"
}
