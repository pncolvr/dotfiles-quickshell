#!/usr/bin/env bash
set -euo pipefail
launcher=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/launcher.sh
exec bash "$launcher" n8n "$@"
