"""Build the input corpus for the mutation study in corpus/:
  syn_*.tba   the synthetic TBAs of evaluation/synthetic_tba_bench.ml (ported by hand, same
              structure; event ids 0..3 are e0..e3, clock names cx,cy,cz,cw,cu,cv = 0..5)
  rnd_*.tba   random TBAs (fuzzing inputs), kept when the language is "interesting": the TBA
              accepts between 3% and 90% of the test words of lang_cmp
Run inside WSL:  python3 make_corpus.py
"""
import os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'corpus')
LC = os.path.expanduser('~/mut/exe/lang_cmp')
os.makedirs(OUT, exist_ok=True)

def write(name, ne, nc, init, nst, acc, trans):
    """trans: list of (src, dst, label, guard, resets); label like ['0+','1-'], guard like ['0<=5']"""
    p = os.path.join(OUT, name + '.tba')
    with open(p, 'w') as f:
        f.write('events %s\nclocks %d\ninit %d\nstates %d\nacc %s\n' % (' '.join('e%d' % i for i in range(ne)), nc, init, nst, ' '.join(map(str, acc))))
        for (s, d, lab, g, r) in trans:
            f.write('t %d %d | %s | %s | %s\n' % (s, d, ' '.join(lab), ' '.join(g), ' '.join(map(str, r))))
    return p

cx, cy, cz, cw, cu, cv = range(6)
T = lambda a: '%d+' % a
F = lambda a: '%d-' % a
le = lambda c, b: '%d<=%g' % (c, b)
ge = lambda c, b: '%d>=%g' % (c, b)

def e(src, dst, lab=(), g=(), r=()):
    return (src, dst, list(lab), list(g), list(r))

syn = {
 'stable': (1, 0, [e(0, 0, [T(0)])], [0]),
 'redundant_guard': (2, 0, [e(0, 1, [T(0)], [le(cx, 5), le(cx, 3)], [cx]), e(1, 1, [], [le(cx, 5)])], [1]),
 'contradictory_guard': (2, 0, [e(0, 1, [T(0)], [ge(cx, 3), le(cx, 2)]), e(1, 1)], [1]),
 'unsatisfiable_label': (2, 0, [e(0, 1, [T(0), F(0)]), e(1, 1)], [1]),
 'isolated_source': (3, 0, [e(0, 0, [T(0)]), e(2, 1, [T(1)])], [0, 1]),
 'dead_reset': (2, 0, [e(0, 1, [T(0)], [], [cz]), e(1, 1, [], [], [cz])], [1]),
 'normalization_dead_reset': (2, 0, [e(0, 1, [T(0)], [], [cx]), e(1, 1, [T(1)], [ge(cx, 0)])], [1]),
 'synchronous_clock_merge': (2, 0, [e(0, 1, [T(0)], [], [cx, cy]), e(1, 1, [T(1)], [le(cx, 4)]), e(1, 1, [T(2)], [le(cy, 6)])], [1]),
 'duplicate_transition': (2, 0, [e(0, 1, [T(0)], [le(cx, 5)], [cx]), e(0, 1, [T(0)], [le(cx, 3)], [cx]), e(1, 1, [], [le(cx, 6)])], [1]),
 'equivalent_locations': (3, 0, [e(0, 1, [T(0)]), e(0, 2, [T(0)]), e(1, 1, [T(1)]), e(2, 2, [T(1)])], [1, 2]),
 'disjunctive_invariant_export': (3, 0, [e(0, 1, [T(0)]), e(1, 1, [T(1)], [le(cx, 3)]), e(1, 1, [T(1)], [le(cy, 4)])], [1]),
 'backward_tightening': (2, 0, [e(0, 1, [T(0)], [le(cx, 5)]), e(1, 1, [T(1)], [le(cx, 2)])], [1]),
 'forward_lower_bound': (3, 0, [e(0, 1, [T(0)], [ge(cx, 2)]), e(1, 2, [T(1)], [le(cx, 5)]), e(2, 2, [T(2)])], [2]),
 'forward_contradiction_cascade': (6, 0, [e(0, 0, [T(3)]), e(0, 1, [T(0)], [ge(cx, 2)]), e(1, 2, [T(1)], [le(cx, 1)]), e(1, 3, [T(2)], [le(cx, 10)]), e(2, 4, [T(3)]), e(4, 5, [F(0)]), e(3, 3, [T(0)])], [0, 3]),
 'backward_contradiction_cascade': (5, 0, [e(0, 0, [T(3)]), e(0, 1, [T(0)], [ge(cx, 2)]), e(1, 2, [T(1)], [le(cx, 1)]), e(2, 3, [T(2)], [le(cx, 1)]), e(3, 4, [F(0)], [le(cx, 1)])], [0]),
 'clock_merge_contradiction_cascade': (5, 0, [e(0, 1, [T(3)], [], [cx, cy]), e(1, 1, [T(3)], [le(cx, 10), le(cy, 10)], [cx, cy]), e(0, 2, [T(0)], [], [cx, cy]), e(2, 3, [T(1)], [ge(cx, 5), le(cy, 3)]), e(3, 4, [T(2)])], [1]),
}
# parameterized families (small sizes)
for k in (2, 4):
    syn['duplicate_%d' % k] = (2, 0, [e(0, 1, [T(0)]) for _ in range(k)] + [e(1, 1, [T(1)])], [1])
for k in (2, 4):
    syn['unreachable_%d' % k] = (k + 2, 0, [e(0, 0, [T(0)])] + [e(j + 1, j + 2, [T(1)]) for j in range(k)], [0])
for k in (2, 4):
    syn['redundant_bounds_%d' % k] = (2, 0, [e(0, 1, [T(0)], [le(cx, k - j) for j in range(k)]), e(1, 1, [T(1)])], [1])
cl = [cx, cy, cz, cw, cu, cv]
lab3 = lambda i: [('0+' if i & 1 else '0-'), ('1+' if i & 2 else '1-'), ('2+' if i & 4 else '2-')]
for k in (2, 3, 4):
    syn['sync_clocks_%d' % k] = (2, 0, [e(0, 1, [T(0)], [], cl[:k])] + [e(1, 1, lab3(i), [le(x, i + 2)]) for i, x in enumerate(cl[:k])], [1])
    syn['invariant_disjunction_%d' % k] = (2, 0, [e(0, 1, [T(0)])] + [e(1, 1, lab3(i), [le(x, i + 2)]) for i, x in enumerate(cl[:k])], [1])
for name, (n, init, trans, acc) in syn.items():
    write('syn_' + name, 4 if name not in ('stable',) and 'sync' not in name and 'invariant_disj' not in name else 4, 6, init, n, acc, trans)

# random TBAs
def rnd_tba(rng):
    nl = rng.randint(2, 5); nc = rng.randint(1, 3); ne = 3
    acc = sorted(rng.sample(range(nl), rng.randint(1, max(1, nl // 2))))
    trans = []
    for l in range(nl):
        for _ in range(rng.randint(1, 3)):
            d = rng.randrange(nl)
            r = rng.random()
            lab = [] if r < 0.15 else ([T(rng.randrange(ne))] if r < 0.8 else [F(rng.randrange(ne))])
            g = []
            for _ in range(rng.choice([0, 0, 1, 1, 2])):
                c = rng.randrange(nc); op = rng.choice(['<=', '<', '>=', '>', '==']) if rng.random() < 0.8 else rng.choice(['<=', '>='])
                g.append('%d%s%d' % (c, op, rng.choice([0, 1, 2, 3, 4, 5])))
            rs = [c for c in range(nc) if rng.random() < 0.35]
            trans.append((l, d, lab, g, rs))
    return nl, nc, 0, acc, trans

rng = random.Random(20261109)
kept = 0; tried = 0
while kept < 120 and tried < 20000:
    tried += 1
    nl, nc, init, acc, trans = rnd_tba(rng)
    p = write('rnd_tmp', 3, nc, init, nl, acc, trans)
    can = os.path.join(OUT, 'rnd_tmp.can')
    subprocess.run([sys.executable, os.path.join(HERE, 'to_canon.py'), 'tba', p, can], check=True)
    out = subprocess.run([LC, can, can, '600', '7'], capture_output=True, text=True).stdout
    acc_a = int(out.split('accA=')[1].split()[0]); pairs = int(out.split('pairs=')[1].split()[0])
    if 0.03 <= acc_a / pairs <= 0.9:
        write('rnd_%03d' % kept, 3, nc, init, nl, acc, trans); kept += 1
for f in ('rnd_tmp.tba', 'rnd_tmp.can'):
    try: os.remove(os.path.join(OUT, f))
    except OSError: pass
print('synthetic:', len(syn), 'random kept:', kept, 'of', tried)
