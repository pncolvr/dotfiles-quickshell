#!/usr/bin/env bash
source "$WORKSPACE/handle-virtual-machine.sh"

function kill_all () {
    killall sdl-freerdp3
    killall ssh
    shutdown_vm win11
}

function shutdown_vm () {
    local vm_name=$1
    stop_virtual_machine "$vm_name"
}

function handle_picked_option() {
    local picked=$1
    case "$picked" in
        kill) kill_all;;
        # todo: fix when assoc_array is used
        # todo: ask which vm to shutdown
        "shutdown vm") shutdown_vm win11;;
    esac
}