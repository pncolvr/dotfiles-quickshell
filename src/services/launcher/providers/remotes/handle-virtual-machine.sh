#!/usr/bin/env bash

# TODO: move this script out of here

TEMP_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"

function monitor_virtual_machine() {
    local server=$1
    local port=$2
    local name=$3
    local max_attempts=60
    attempt=0
    while (( attempt < max_attempts )); do
        if nc -z "$server" "$port" 2>/dev/null; then
            break
        else
            (( attempt++ ))
            sleep 1
        fi
    done
}

function start_virtual_machine() {
    local name=$1
    virsh -c qemu:///system start "$name" >> /dev/null 2>&1
}

function stop_virtual_machine() {
    local name=$1
    virsh -c qemu:///system shutdown "$name"
}