#!/usr/bin/env bash
# Read-only, fixed SQL templates. Requests arrive on stdin; contents never enter argv.
set -euo pipefail
umask 077
trap 'printf "{\"error\":\"Clipboard search unavailable.\",\"rows\":[]}\n"' ERR
path=${1:?}
request=$(cat)
jq -e 'type=="object" and (.engine=="indexed" or .engine=="fuzzy")
    and (.query|type=="string" and length<=4096) and (.kind=="" or .kind=="image" or .kind=="text")
    and (.pinned|type=="boolean") and (.limit|type=="number" and floor==. and .>=1 and .<=1001)
    and (.offset|type=="number" and floor==. and .>=0 and .<=100000)' <<< "$request" >/dev/null
engine=$(jq -r '.engine' <<< "$request")
kind=$(jq -r '.kind' <<< "$request")
pinned=$(jq -r '.pinned' <<< "$request")
limit=$(jq -r '.limit' <<< "$request")
offset=$(jq -r '.offset' <<< "$request")
# unicode61 token boundaries: treat punctuation/operators as ordinary separators.
match=$(jq -r '[.query | scan("[\\p{L}\\p{N}\\p{Co}][\\p{L}\\p{N}\\p{Co}\\p{Mn}\\p{Mc}]*") | "\"" + . + "\"*"] | join(" AND ")' <<< "$request")
where='1'
[[ -z $kind ]] || where+=" AND c.kind='$kind'"
[[ $pinned == false ]] || where+=' AND c.pinned=1'
columns='c.id,c.mime,c.kind,c.bytes,c.updated_at,c.pinned,substr(c.text,1,240) AS preview'
from='clipboard c'
order='c.updated_at DESC,c.id DESC'
if [[ $engine == fuzzy ]]; then
    columns+=',c.text AS search'
    limit=-1; offset=0
elif [[ -n $match ]]; then
    # Encode as a SQL text literal via hex, not shell/SQL interpolation of raw input.
    hex=$(printf %s "$match" | od -An -v -tx1 | tr -d ' \n')
    from+=' JOIN clipboard_fts ON clipboard_fts.rowid=c.rowid'
    where+=" AND clipboard_fts MATCH CAST(X'$hex' AS TEXT)"
    order="bm25(clipboard_fts),$order"
elif [[ $(jq -r '.query|test("\\S")' <<< "$request") == true ]]; then
    where+=' AND 0'
fi
# Keep one snapshot for each page. No writes, no client-provided SQL.
printf '.timeout 1500\nPRAGMA query_only=ON;\nSELECT %s FROM %s WHERE %s ORDER BY %s LIMIT %s OFFSET %s;\n' \
    "$columns" "$from" "$where" "$order" "$limit" "$offset" |
    sqlite3 -readonly -json "$path" 2>/dev/null | jq -cs '{rows:(.[0] // []),error:""}'
