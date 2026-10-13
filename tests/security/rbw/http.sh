#!/usr/bin/env bash
set -euo pipefail
while IFS= read -r line; do [[ $line == $'\r' || -z $line ]] && break; done
printf 'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n'
cat "$RBW_TEST_ROOT/site.html"
