"""Trace the reachable (location, valuation) sets of a canonical automaton (lang_cmp format) on a lasso word.
usage: python3 trace_can.py file.can "P:e,d e,d ..." "L:e,d ..." v0,v0,.. steps
Semantics as in evaluation/mutation/lang_cmp.cpp (guard on the valuation at the event, reset, then delay)."""
import sys
def load(p):
    A = dict(tr=[], inv={}, acc=set(), init=0, nc=0)
    for l in open(p):
        w = l.split()
        if not w: continue
        if w[0] == 'C': A['nc'] = int(w[1])
        elif w[0] == 'I': A['init'] = int(w[1])
        elif w[0] == 'A': A['acc'] = set(map(int, w[2:]))
        elif w[0] == 'V':
            k = int(w[2]); A['inv'].setdefault(int(w[1]), []).extend((int(w[3 + 2 * i]), int(w[4 + 2 * i])) for i in range(k))
        elif w[0] == 'T':
            src, dst, mask, ng = map(int, w[1:5]); i = 5; g = []
            for _ in range(ng): g.append(tuple(map(int, w[i:i + 4]))); i += 4
            nr = int(w[i]); rs = list(map(int, w[i + 1:i + 1 + nr]))
            A['tr'].append((src, dst, mask, g, rs))
    return A
def holds(a, v):
    k, c1, c2, b = a
    return [v[c1] <= b, v[c1] < b, v[c1] >= b, v[c1] > b, v[c1] == b, v[c1] - v[c2] <= b][k]
A = load(sys.argv[1])
pre = [tuple(map(int, x.split(','))) for x in sys.argv[2].split() if x != '-']
lp = [tuple(map(int, x.split(','))) for x in sys.argv[3].split()]
v0 = tuple(map(int, sys.argv[4].split(',')))
steps = int(sys.argv[5])
cur = {(A['init'], v0)}
for n in range(steps):
    e, d = pre[n] if n < len(pre) else lp[(n - len(pre)) % len(lp)]
    nxt = set(); why = []
    for (loc, v) in cur:
        for (s, t, m, g, rs) in A['tr']:
            if s != loc or not (m >> e) & 1 or not all(holds(a, v) for a in g): continue
            r = list(v)
            for c in rs: r[c] = 0
            r = tuple(x + d for x in r)
            if all(r[c] <= b for (c, b) in A['inv'].get(t, [])): nxt.add((t, r))
    cur = nxt
    print(n, 'event', e, 'delay', d, sorted(cur)[:6], 'acc' if any(l in A['acc'] for l, _ in cur) else '')
    if not cur: break
