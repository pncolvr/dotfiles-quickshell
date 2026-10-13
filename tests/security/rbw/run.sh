#!/usr/bin/env bash
# All fixtures are synthetic; no vault login, clipboard capture or account writes.
set -euo pipefail
rbw_test_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for check in protocol picker-errors enum-compat backend browser launcher cli config; do
    bash "$rbw_test_root/$check.sh"
done
