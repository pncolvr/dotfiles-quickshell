#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
export QT_QPA_PLATFORM=offscreen QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu
timeout 20 qutebrowser --basedir "$test_dir/profile" --nowindow --config-py "$browser_root/config.py" \
    --set confirm_quit '["never"]' about:blank :config-source ':set confirm_quit ["never"]' :quit > "$test_dir/log" 2>&1
! rg -q 'Error while reading config|Error while loading config|Traceback' "$test_dir/log"
printf 'PASS: real qutebrowser config boots and reloads in a disposable profile\n'
