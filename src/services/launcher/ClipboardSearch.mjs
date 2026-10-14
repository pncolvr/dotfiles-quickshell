import {searchPattern, prepareRows, filterPrepared} from './Search.mjs';

let generation = -1;
let rows = [];
let previous = null;

WorkerScript.onMessage = function(message) {
    if (message.clear) { rows = []; previous = null; generation = -1; WorkerScript.sendMessage({cleared:true}); return; }
    const started = Date.now();
    if (Array.isArray(message.rows)) {
        generation = message.generation;
        rows = prepareRows(message.rows);
        previous = null;
    }
    if (generation !== message.generation) return;
    const pattern = searchPattern(message.query, message.smartCase);
    const normalized = pattern.needles.join(' ');
    const reused = previous !== null && previous.sensitive === pattern.sensitive
        && previous.fuzzy === message.fuzzy && previous.pinnedOnly === message.pinnedOnly && previous.kind === message.kind
        && normalized.startsWith(previous.normalized);
    const candidates = reused ? previous.indices : rows.map(row => row.index);
    const indices = filterPrepared(rows, candidates, pattern, message.fuzzy, message.pinnedOnly, message.kind);
    previous = {normalized, sensitive: pattern.sensitive, fuzzy: message.fuzzy,
        pinnedOnly: message.pinnedOnly, kind: message.kind, indices};
    WorkerScript.sendMessage({generation, request: message.request, indices,
        reused, candidates: candidates.length, duration: Date.now() - started});
};
