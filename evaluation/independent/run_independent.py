"""Verified optimizer and export on TBAs that no MTL translator produced.

Two families of input, both generated here and neither related to the MTL front end or to the generators of
evaluation/mutation:
  graph    random timed Buchi graphs: 6-12 locations, 2-4 clocks, 3-4 events, constants up to 8
  monitor  parameterized specification-style monitors (bounded-response chains with timeouts, periodic events with
           jitter, watchdogs, rate limiters, two-clock windows), each with optional redundant clocks (reset in
           lockstep), dead resets, unreachable branches and duplicated edges, which are what the passes remove

For every input the unmutated tba_opt (the extracted optimizer and exporter) is run with the maximal-delay and the
all-copy export, and the language of each output (the optimized TBA and the exported UPPAAL XML) is compared with the
input's by the bounded word test lang_cmp (the oracle of evaluation/mutation, WORDS words per pair).
Run inside WSL after evaluation/mutation/setup_base.sh:  python3 run_independent.py [N_GRAPH] [N_MONITOR] [WORDS]
Writes results/independent.tsv (one row per input and policy) and results/independent_summary.txt."""
import os, sys, random, subprocess, shutil, re, glob
HERE = os.path.dirname(os.path.abspath(__file__))
MUT = os.path.join(HERE, '..', 'mutation')
sys.path.insert(0, MUT)
import mut_lib, to_canon
from mut_lib import sh, events_of, HOME
LC = HOME + '/mut/exe/lang_cmp_new'   # lang_cmp.cpp built with the LANGCMP_EXTRA option
os.environ['LANGCMP_EXTRA'] = os.environ.get('LANGCMP_EXTRA', '60')

NG = int(sys.argv[1]) if len(sys.argv) > 1 else 300
NM = int(sys.argv[2]) if len(sys.argv) > 2 else 300
WORDS = int(sys.argv[3]) if len(sys.argv) > 3 else 20000
EXE = HOME + '/mut/exe/base_tba_opt.exe'
WORK = HOME + '/mut/independent'
CORP = WORK + '/corpus'
T = lambda a: '%d+' % a
F = lambda a: '%d-' % a


def write(path, ne, nc, init, nst, acc, trans):
    with open(path, 'w') as f:
        f.write('events %s\nclocks %d\ninit %d\nstates %d\nacc %s\n' % (' '.join('e%d' % i for i in range(ne)), nc, init, nst, ' '.join(map(str, acc))))
        for (s, d, lab, g, r) in trans:
            f.write('t %d %d | %s | %s | %s\n' % (s, d, ' '.join(lab), ' '.join(g), ' '.join(map(str, r))))


def graph_tba(rng):
    nl = rng.randint(6, 12); nc = rng.randint(2, 4); ne = rng.randint(3, 4)
    acc = sorted(rng.sample(range(nl), rng.randint(1, 3)))
    trans = []
    for l in range(nl):
        for _ in range(rng.randint(1, 3)):
            d = rng.randrange(nl) if rng.random() < 0.6 else (l + 1) % nl
            lab = [] if rng.random() < 0.1 else ([T(rng.randrange(ne))] if rng.random() < 0.85 else [F(rng.randrange(ne))])
            g = []
            for _ in range(rng.choice([0, 1, 1, 2, 2, 3])):
                c = rng.randrange(nc)
                op = rng.choice(['<=', '<', '>=', '>', '=='])
                g.append('%d%s%d' % (c, op, rng.randint(0, 8)))
            rs = [c for c in range(nc) if rng.random() < 0.4]
            trans.append((l, d, lab, g, rs))
    return ne, nc, 0, nl, acc, trans


def monitor_tba(rng):
    """Specification-style monitor.  Locations are added by a template; clocks: 0.. real ones, then redundant copies."""
    kind = rng.choice(['response', 'periodic', 'watchdog', 'ratelimit', 'window'])
    ne = 3  # e0 request/event, e1 reply/kick, e2 other
    trans = []; acc = []
    d1 = rng.randint(1, 6); d2 = rng.randint(1, 6); j = rng.randint(0, 3)
    if kind == 'response':      # chain of stages with timeouts; violation = timeout in any stage (accepting sink)
        k = rng.randint(2, 4); nc = 1
        # locations 0..k-1 stages, k = done loop, k+1 = violation sink
        for s in range(k):
            dd = rng.randint(1, 6)
            trans.append((s, s + 1 if s + 1 < k else k, [T(1)], ['0<=%d' % dd], [0]))
            trans.append((s, k + 1, [], ['0>%d' % dd], []))
            trans.append((s, s, [F(1)], ['0<=%d' % dd], []))
        trans.append((k, 0, [T(0)], [], [0])); trans.append((k, k, [F(0)], [], []))
        trans.append((k + 1, k + 1, [], [], [])); acc = [k + 1]; nl = k + 2
    elif kind == 'periodic':    # event e0 must recur with period in [d1, d1+j]; violation otherwise
        nc = 1; nl = 3
        trans = [(0, 1, [T(0)], [], [0]),
                 (1, 1, [F(0)], ['0<=%d' % (d1 + j)], []),
                 (1, 1, [T(0)], ['0>=%d' % d1, '0<=%d' % (d1 + j)], [0]),
                 (1, 2, [T(0)], ['0<%d' % d1], []), (1, 2, [], ['0>%d' % (d1 + j)], []),
                 (2, 2, [], [], [])]
        acc = [2]
    elif kind == 'watchdog':    # accept when no kick for more than d1
        nc = 1; nl = 2
        trans = [(0, 0, [T(1)], [], [0]), (0, 0, [F(1)], ['0<=%d' % d1], []), (0, 1, [], ['0>%d' % d1], []), (1, 1, [], [], [])]
        acc = [1]
    elif kind == 'ratelimit':   # two events closer than d1 are a violation
        nc = 1; nl = 3
        trans = [(0, 1, [T(0)], [], [0]), (1, 1, [F(0)], [], []), (1, 1, [T(0)], ['0>=%d' % d1], [0]),
                 (1, 2, [T(0)], ['0<%d' % d1], []), (2, 2, [], [], [])]
        acc = [2]
    else:                       # window: e0 then e1 within [d1, d1+d2] on one clock while another clock bounds the whole episode
        nc = 2; nl = 4
        trans = [(0, 1, [T(0)], [], [0, 1]),
                 (1, 2, [T(1)], ['0>=%d' % d1, '0<=%d' % (d1 + d2)], []),
                 (1, 3, [], ['1>%d' % (d1 + d2 + 2)], []),
                 (2, 0, [], [], []), (3, 3, [], [], [])]
        acc = [2, 3]
    # decorations that give the passes work
    real = nc
    for _ in range(rng.randint(0, 2)):       # redundant clock reset in lockstep with clock 0
        c = nc; nc += 1
        trans = [(s, d, lab, [a.replace('0', str(c), 1) if (a.startswith('0') and rng.random() < 0.5) else a for a in g],
                  list(r) + ([c] if 0 in r else [])) for (s, d, lab, g, r) in trans]
    if rng.random() < 0.7:                    # dead resets: reset a clock never tested afterwards
        c = nc; nc += 1
        trans = [(s, d, lab, g, r + [c] if rng.random() < 0.5 else r) for (s, d, lab, g, r) in trans]
    if rng.random() < 0.6:                    # unreachable branch
        trans.append((nl, 0, [T(0)], ['0<=%d' % d1], [0])); nl += 1
    if rng.random() < 0.6 and trans:          # duplicated and subsumed edges
        trans.append(trans[rng.randrange(len(trans))])
        s, d, lab, g, r = trans[rng.randrange(len(trans))]
        trans.append((s, d, lab, g + ['0>=0'], r))
    return ne, nc, 0, nl, sorted(set(acc)), trans


def accepted_fraction(p):
    can = p[:-4] + '.can'; to_canon.from_tba(p, can)
    out = subprocess.run([LC, can, can, '400', '7'], capture_output=True, text=True).stdout
    a = int(out.split('accA=')[1].split()[0]); pr = int(out.split('pairs=')[1].split()[0])
    return a / pr


def counts(p):
    ns = nt = 0
    for l in open(p):
        if l.startswith('states'): ns = int(l.split()[1])
        if l.startswith('t '): nt += 1
    return ns, nt


def make_corpus():
    shutil.rmtree(CORP, ignore_errors=True); os.makedirs(CORP)
    for fam, gen, n, seed in (('graph', graph_tba, NG, 20261201), ('monitor', monitor_tba, NM, 20261202)):
        rng = random.Random(seed); kept = 0; tries = 0
        while kept < n and tries < 40 * n:
            tries += 1
            ne, nc, init, nl, acc, trans = gen(rng)
            if nc > 6 or not acc:
                continue
            p = '%s/%s_%04d.tba' % (CORP, fam, kept)
            write(p, ne, nc, init, nl, acc, trans)
            try:
                fr = accepted_fraction(p)
            except Exception:
                continue
            if 0.01 <= fr <= 0.95:
                kept += 1
            else:
                os.remove(p)
        print(fam, kept, 'of', tries, 'tries', flush=True)


def main():
    make_corpus()
    files = sorted(glob.glob(CORP + '/*.tba'))
    out = WORK + '/out'; shutil.rmtree(out, ignore_errors=True); os.makedirs(out)
    rows = []
    for p in files:
        name = os.path.basename(p)[:-4]
        evs = events_of(p)
        ns0, nt0 = counts(p)
        a = out + '/' + name + '.in.can'; to_canon.from_tba(p, a)
        for pol, flags in mut_lib.POLICIES:
            base = out + '/' + name + '.' + pol
            rc, so, se = sh([EXE, '-o', base, '-dump', base + '.opt.tba'] + flags + [p], timeout=60)
            row = dict(name=name, pol=pol, rc=rc, ns0=ns0, nt0=nt0, ns1='', nt1='', warn=int('init_free false' in so),
                       mm_opt='', mm_xml='')
            if rc == 0 and os.path.exists(base + '.xml'):
                kinds = [('xml', base + '.xml')] + ([('tba', base + '.opt.tba')] if pol == 'md' else [])
                for typ, f in kinds:
                    b = out + '/' + name + '.' + pol + '.' + typ + '.can'
                    try:
                        (to_canon.from_xml(f, evs, b) if typ == 'xml' else to_canon.from_tba(f, b))
                        r2, o2, e2 = sh([LC, a, b, str(WORDS), '31'], timeout=900)
                        m = re.search(r'mismatch=(\d+)', o2)
                        v = int(m.group(1)) if m else -1
                    except Exception:
                        v = -2
                    row['mm_xml' if typ == 'xml' else 'mm_opt'] = v
                if pol == 'md' and os.path.exists(base + '.opt.tba'):
                    row['ns1'], row['nt1'] = counts(base + '.opt.tba')
            rows.append(row)
        print(name, flush=True) if len(rows) % 100 == 0 else None
    os.makedirs(HERE + '/results', exist_ok=True)
    cols = ['name', 'pol', 'rc', 'ns0', 'nt0', 'ns1', 'nt1', 'warn', 'mm_opt', 'mm_xml']
    with open(HERE + '/results/independent.tsv', 'w') as f:
        f.write('\t'.join(cols) + '\n')
        for r in rows:
            f.write('\t'.join(str(r[c]) for c in cols) + '\n')
    # summary
    L = []
    for fam in ('graph', 'monitor'):
        R = [r for r in rows if r['name'].startswith(fam)]
        ins = sorted(set(r['name'] for r in R))
        ok = [r for r in R if r['rc'] == 0]
        mm = [r for r in ok if r['mm_xml'] not in ('', 0) or r['mm_opt'] not in ('', 0)]
        md = [r for r in ok if r['pol'] == 'md' and r['nt1'] != '']
        t0 = sum(r['nt0'] for r in md); t1 = sum(r['nt1'] for r in md)
        s0 = sum(r['ns0'] for r in md); s1 = sum(r['ns1'] for r in md)
        red = sum(1 for r in md if r['nt1'] < r['nt0'])
        L.append('%s: %d inputs, %d runs ok of %d, language mismatches %d, init_free warnings %d, transitions %d -> %d, locations %d -> %d, inputs with fewer transitions %d'
                 % (fam, len(ins), len(ok), len(R), len(mm), sum(r['warn'] for r in ok if r['pol'] == 'md'), t0, t1, s0, s1, red))
    open(HERE + '/results/independent_summary.txt', 'w').write('\n'.join(L) + '\n')
    print('\n'.join(L))


main()
