#!/usr/bin/env bash
# Compatibility entrypoint; the native service owns records and connections.
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/../../launcher.sh" remotes "$@"
