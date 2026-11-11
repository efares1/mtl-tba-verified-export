"""Upper bound on what a liveness-based clock allocation could save beyond the verified optimizer.

For each requirement (benchmark patterns F/R/N in both polarities, and the random formulas) the tool
mtl2tba writes the optimized and exported automaton as an UPPAAL template Property.  On that automaton
we compute, per clock, where its value can still be read (backward liveness over guards and
invariants; a reset kills the old value), build the interference graph and colour it greedily.  Two
clocks that never interfere could share one physical clock, so the number of colours is an upper bound
on the clocks a clock-reuse pass needs, and the size of the largest clique found is a lower bound on any
allocation of this kind.  The analysis is sound as a bound on what reuse can do, it does not construct the pass.

Interference (a conservative, standard definition):
  - x and y interfere if both are live at the entry of some location;
  - a reset of x on an edge interferes with every clock live at the target of that edge, because the
    reset overwrites a shared physical clock.

Usage (WSL): python3 clock_liveness.py OUT.tsv [EXE] ; reads formulas.tsv and random_formulas_4col.tsv.
"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp

OUT = sys.argv[1]
EXE = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
LIMIT = int(os.environ.get('LIMIT', '120'))
IDS = os.environ.get('IDS', 'F1 F2 F3 F3b F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 R1 R2 R3 R4 R5 R6 N1 N2 N3 N4 N5 N6').split()
CLK = re.compile(r'[A-Za-z_]\w*')


def read_clocks(expr, clocks):
    return {c for c in CLK.findall(expr or '') if c in clocks}


def analyse(a):
    # clocks are renamed NEG_x0, NEG_x1, ... by the parser
    clocks = {'%s_%s' % (a.name, x) for x in a.clocks}
    if not clocks:
        return 0, 0, 0, 0
    live = {l: set() for l in a.locs}
    for l, (lab, inv, com) in a.locs.items():
        live[l] = read_clocks(inv, clocks)
    changed = True
    while changed:
        changed = False
        for (s, t, ev, g, rs, _) in a.edges:
            new = read_clocks(g, clocks) | (live[t] - set(rs))
            if not new <= live[s]:
                live[s] |= new
                changed = True
    edges_i = set()

    def clique(S):
        S = sorted(S)
        for i in range(len(S)):
            for j in range(i + 1, len(S)):
                edges_i.add((S[i], S[j]))
    for l in a.locs:
        clique(live[l])
    for (s, t, ev, g, rs, _) in a.edges:
        for r in rs:
            for c in live[t]:
                if c != r:
                    edges_i.add(tuple(sorted((r, c))))
    adj = {c: set() for c in clocks}
    for (x, y) in edges_i:
        adj[x].add(y)
        adj[y].add(x)
    # DSATUR colouring
    col = {}
    while len(col) < len(clocks):
        u = max((c for c in clocks if c not in col), key=lambda c: (len({col[n] for n in adj[c] if n in col}), len(adj[c])))
        used = {col[n] for n in adj[u] if n in col}
        k = 0
        while k in used:
            k += 1
        col[u] = k
    colours = max(col.values()) + 1
    # greedy clique (lower bound)
    best = 1
    for c in clocks:
        cl = [c]
        for d in sorted(adj[c], key=lambda d: -len(adj[d])):
            if all(d in adj[e] for e in cl):
                cl.append(d)
        best = max(best, len(cl))
    maxlive = max(len(v) for v in live.values())
    return len(clocks), colours, best, maxlive


def run(i, formula, pol, W):
    f = formula if pol == 'pos' else '!(%s)' % formula
    base = os.path.join(W, 'o')
    try:
        r = subprocess.run([EXE, '-nopdf', '-all-copy', '-o', base, f], cwd=W, capture_output=True, text=True, timeout=LIMIT)
    except subprocess.TimeoutExpired:
        return None
    if r.returncode != 0 or not os.path.exists(base + '.xml'):
        return None
    a = tp.from_xml('NEG', base + '.xml')
    return analyse(a)


recs = []
for fn in ('formulas.tsv', 'random_formulas_4col.tsv'):
    for l in open(os.path.join(HERE, fn), encoding='utf8'):
        if l.startswith('#') or not l.strip():
            continue
        p = l.rstrip('\n').split('\t')
        if len(p) < 3:
            continue
        if fn == 'formulas.tsv' and p[0] not in IDS:
            continue
        recs.append((p[0], p[2]))
W = tempfile.mkdtemp()
try:
    with open(OUT, 'w', encoding='utf8') as o:
        o.write('id\tpolarity\tclocks\tcolours\tclique\tmax_live\n')
        for i, f in recs:
            for pol in ('pos', 'neg'):
                r = run(i, f, pol, W)
                row = [i, pol] + (list(map(str, r)) if r else ['NA'] * 4)
                o.write('\t'.join(row) + '\n')
                o.flush()
finally:
    shutil.rmtree(W, ignore_errors=True)
