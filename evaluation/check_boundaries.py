"""Simulate the exported automata of boundary_tests.tsv on finite timed words.

Usage: python check_boundaries.py [directory-with-<id>.dot]
The automata are produced by run_boundary_tests.sh (mtl2tba on the negation
column).  Every clock reads the time of the first event at that event, as in
UPPAAL (clocks start at 0 at time 0).  A violation is reported when some run
on the prefix reaches an accepting location with a loop on every event and no
invariant.  This is an implementation check of the tool, not a substitute for
the proof.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def parse_constraint(c):
    c = c.strip()
    m = re.fullmatch(r'(x\d+)\s*-\s*(x\d+)\s*(<=|<)\s*(-?[\d.]+)', c)
    if m:
        x, y, op, b = m.groups()
        b = float(b)
        return lambda v: (v[x] - v[y] <= b) if op == '<=' else (v[x] - v[y] < b)
    m = re.fullmatch(r'(x\d+)\s*(<=|<|>=|>|==)\s*(-?[\d.]+)', c)
    if not m:
        raise ValueError(c)
    x, op, b = m.groups()
    b = float(b)
    return {'<=': lambda v: v[x] <= b, '<': lambda v: v[x] < b,
            '>=': lambda v: v[x] >= b, '>': lambda v: v[x] > b,
            '==': lambda v: v[x] == b}[op]


def parse_dot(path):
    s = open(path, encoding='utf-8').read()
    init = re.search(r'init -> (L\d+);', s).group(1)
    acc, inv = set(), {}
    for m in re.finditer(r'\n\s*(L\d+) \[shape=(\w+), label="([^"]*)"\]', s):
        name, shape, label = m.groups()
        if shape == 'doublecircle':
            acc.add(name)
        parts = label.split('\\n')[1:]
        inv[name] = [parse_constraint(c) for p in parts for c in p.split('&&')]
    # symbolic transitions (Coq: symbolic): one line per case "guard: events"
    # or "events", and a last line "x, y := 0" for the resets
    edges = []
    for m in re.finditer(r'\n\s*(L\d+) -> (L\d+) \[label="([^"]*)"\]', s):
        src, tgt, label = m.groups()
        cases, resets = [], []
        for ln in label.split('\\n'):
            if ':=' in ln:
                resets = re.findall(r'x\d+', ln)
                continue
            if ': ' in ln:
                g, ev = ln.split(': ', 1)
                guard = [parse_constraint(c) for c in g.split('&&')]
            else:
                guard, ev = [], ln
            cases.append((guard, [e.strip() for e in ev.split('|')]))
        edges.append((src, tgt, cases, resets))
    clocks = sorted(set(re.findall(r'\bx\d+\b', s)))
    sinks = {l for l in acc if not inv.get(l)
             and any(e[0] == l and e[1] == l and any(c[1] == ['any'] and not c[0] for c in e[2])
                     for e in edges)}
    return init, edges, inv, clocks, sinks


def event_matches(events, a, alphabet):
    if events == ['any']:
        return True
    if events == ['false']:
        return False
    if a in events:
        return True
    return 'other' in events and a not in alphabet


def violation(path, word, alphabet):
    init, edges, inv, clocks, sinks = parse_dot(path)
    t0 = word[0][1]
    confs = [(init, {x: t0 for x in clocks})]
    prev = t0
    for i, (a, t) in enumerate(word):
        d = 0.0 if i == 0 else t - prev
        new = []
        for loc, v in confs:
            v = {x: val + d for x, val in v.items()}
            if not all(c(v) for c in inv.get(loc, [])):
                continue
            for src, tgt, cases, resets in edges:
                if src == loc and any(event_matches(ev, a, alphabet) and all(c(v) for c in g)
                                      for g, ev in cases):
                    v2 = dict(v)
                    for x in resets:
                        v2[x] = 0.0
                    if all(c(v2) for c in inv.get(tgt, [])):
                        new.append((tgt, v2))
        confs = new
        prev = t
        if any(loc in sinks for loc, _ in confs):
            return True
    return False


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'boundary_out')
    ok = True
    for line in open(os.path.join(HERE, 'boundary_tests.tsv'), encoding='utf-8'):
        if line.startswith('#') or not line.strip():
            continue
        tid, req, neg, word, exp = line.rstrip('\n').split('\t')
        w = [(e.split('@')[0], float(e.split('@')[1])) for e in word.split()]
        alphabet = set(re.findall(r'\b[a-z]\w*\b', neg)) - {'true', 'false'}
        got = violation(os.path.join(d, tid + '.dot'), w, alphabet)
        res = 'yes' if got else 'no'
        ok = ok and res == exp
        print(f'{tid}\t{req}\t{word}\texpected {exp}\tgot {res}\t{"OK" if res == exp else "FAIL"}')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
