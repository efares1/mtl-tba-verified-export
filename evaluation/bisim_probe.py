"""Probe for a semantic location-merging pass (item B of the review): how many locations of the exported
automaton are bisimilar, and does the quotient change what TChecker explores?

The quotient is the coarsest partition of the locations that respects (a) the accepting mark and the
invariant and (b) the set of outgoing edges (event, guard, reset set, class of the target).  Locations in
one class have the same timed behaviour, because an edge carries its whole timing condition and its
resets, so the quotient accepts the same timed words.  (This is syntactic bisimulation; it is sound but
not complete for timed bisimulation, so it is a lower bound on what a semantic pass could merge.)

For each requirement we report the locations and edges before and after the quotient of the negated
requirement's all-copy export, and the states TChecker stores on the product of the requirement's own
automaton with the negation, before and after.

Usage (WSL): python3 bisim_probe.py OUT.tsv ID...      (ids of formulas.tsv)
"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp

OUT = sys.argv[1]
ONLY = sys.argv[2:]
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
LIMIT = int(os.environ.get('LIMIT', '120'))


def norm_guard(g):
    if not g:
        return ''
    return '&&'.join(sorted({x.strip() for x in g.split('&&') if x.strip()}))


def quotient(a):
    accept = {l: bool(v[0]) for l, v in a.locs.items()}
    inv = {l: norm_guard(v[1]) for l, v in a.locs.items()}
    out = {l: [] for l in a.locs}
    for (s, t, ev, g, rs, _) in a.edges:
        out[s].append((ev, norm_guard(g), tuple(sorted(rs)), t))
    cls = {l: (accept[l], inv[l]) for l in a.locs}
    ids = {c: i for i, c in enumerate(sorted(set(cls.values()), key=str))}
    cls = {l: ids[c] for l, c in cls.items()}
    while True:
        sig = {l: (cls[l], frozenset((e, g, r, cls[t]) for (e, g, r, t) in out[l])) for l in a.locs}
        ids = {c: i for i, c in enumerate(sorted(set(sig.values()), key=str))}
        new = {l: ids[sig[l]] for l in a.locs}
        if len(set(new.values())) == len(set(cls.values())):
            cls = new
            break
        cls = new
    rep = {}
    for l in a.locs:
        rep.setdefault(cls[l], l)
    b = tp.Auto(a.name)
    b.state_based = a.state_based
    b.clocks = set(a.clocks)
    for c, l in rep.items():
        b.locs[l] = a.locs[l]
    b.init = rep[cls[a.init]]
    seen = set()
    for (s, t, ev, g, rs, lab) in a.edges:
        s2, t2 = rep[cls[s]], rep[cls[t]]
        key = (s2, t2, ev, norm_guard(g), tuple(sorted(rs)))
        if rep[cls[s]] != s or key in seen:
            continue
        seen.add(key)
        b.edges.append((s2, t2, ev, g, rs, lab))
    return b


def sh(cmd, cwd=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=LIMIT)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def stored(W, events, first, neg):
    autos = [first, neg]
    labels = ['div']
    for a in autos:
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        labels += ls
    tp.write(os.path.join(W, 'm.tck'), autos, events)
    rc, out, err = sh(['timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc', '-l', ','.join(labels), os.path.join(W, 'm.tck')])
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    s = re.search(r'^STORED_STATES (\S+)', out, re.M)
    return ('nonempty' if v and v.group(1) == 'true' else 'empty' if v else 'NA'), (s.group(1) if s else 'NA')


recs = {}
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    if l.startswith('#') or not l.strip():
        continue
    p = l.rstrip('\n').split('\t')
    recs[p[0]] = p[2]
W = tempfile.mkdtemp()
try:
    with open(OUT, 'w', encoding='utf8') as o:
        o.write('id\tlocs\tedges\tlocs_q\tedges_q\tverdict\tstored\tstored_q\n')
        for i in ONLY:
            f = recs[i]
            events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)) - {'true', 'false'})
            rc, _, _ = sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'ref'), f], cwd=W)
            rc2, _, _ = sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'neg'), '!(%s)' % f], cwd=W)
            if rc or rc2:
                o.write('%s\tNA\n' % i)
                continue
            neg = tp.from_xml('NEG', os.path.join(W, 'neg.xml'))
            q = quotient(tp.from_xml('NEG', os.path.join(W, 'neg.xml')))
            v1, s1 = stored(W, events, tp.from_xml('REF', os.path.join(W, 'ref.xml')), neg)
            v2, s2 = stored(W, events, tp.from_xml('REF', os.path.join(W, 'ref.xml')), q)
            row = [i, len(neg.locs), len(neg.edges), len(q.locs), len(q.edges), v1 if v1 == v2 else v1 + '/' + v2, s1, s2]
            o.write('\t'.join(map(str, row)) + '\n')
            o.flush()
            print('\t'.join(map(str, row)), flush=True)
finally:
    shutil.rmtree(W, ignore_errors=True)
