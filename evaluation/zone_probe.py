"""Zone-graph structure of the positive-form stress workload (posbadall), for ours and CASAAL's automaton through our export.

TChecker's stored states are pairs (location vector, zone).  tck-liveness -C graph writes the explored graph;
this script builds the same products as baselines/run_baselines.py (workload posbadall), runs TChecker with the graph
certificate and reports, per arm: stored states, distinct location vectors, zones per vector (max, mean), edges of the
graph and out-degree.  It does not reimplement zones: all counts are those of TChecker itself.

Usage (WSL): python3 zone_probe.py OUT.tsv LIMIT ID...      (ids R1..R5)"""
import os, re, subprocess, sys, tempfile, shutil, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OPT = os.environ.get('OPT', os.path.expanduser('~/tool_copy/_build/default/src/tba_opt.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
OUT, LIMIT, ONLY = sys.argv[1], int(sys.argv[2]), sys.argv[3:]


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


CLK = re.compile(r'[A-Za-z_]\w*')


def reads(expr, clocks):
    return {c for c in CLK.findall(expr or '') if c in clocks}


def deadreset(a):
    """DIAGNOSTIC (unverified): reset on every edge the clocks that are dead at its target.  A dead clock is never read
    before its next reset, so its value cannot influence the language, but TChecker keeps it in the zone."""
    clocks = {'%s_%s' % (a.name, x) for x in a.clocks}
    live = {l: reads(v[1], clocks) for l, v in a.locs.items()}
    ch = True
    while ch:
        ch = False
        for (s, t, ev, g, rs, _) in a.edges:
            new = reads(g, clocks) | (live[t] - set(rs))
            if not new <= live[s]:
                live[s] |= new
                ch = True
    out = []
    for (s, t, ev, g, rs, lab) in a.edges:
        rr = set(rs)
        for x in clocks:
            if x not in live[t]:
                rr.add(x)
        out.append((s, t, ev, g, sorted(rr), lab))
    a.edges = out
    return a


def product(events, W, first, arm):
    autos = [first, arm]
    labels = ['div']
    for a in autos:
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        if a.state_based and not ls:
            ls = ['acc' + a.name]
            a.locs['unreach'] = (ls, None, False)
        labels += ls
    tp.write(os.path.join(W, 'm.tck'), autos, events)
    return ','.join(labels)


NODE = re.compile(r'^\s*(\d+)\s*\[(.*)\]\s*;?\s*$')
EDGE = re.compile(r'^\s*(\d+)\s*->\s*(\d+)')


def analyse(path):
    vec = {}
    nedges = 0
    outdeg = collections.Counter()
    for line in open(path, encoding='utf8', errors='replace'):
        m = EDGE.match(line)
        if m:
            nedges += 1
            outdeg[m.group(1)] += 1
            continue
        m = NODE.match(line)
        if m:
            attrs = m.group(2)
            v = re.search(r'vloc="([^"]*)"', attrs)
            z = re.search(r'zone="([^"]*)"', attrs)
            vec[m.group(1)] = (v.group(1) if v else '?', z.group(1) if z else '?')
    per = collections.Counter(v for v, z in vec.values())
    zs = collections.defaultdict(set)
    for v, z in vec.values():
        zs[v].add(z)
    n = len(vec)
    diff = re.compile(r'^[^<>=]*[A-Za-z_]\w*-[A-Za-z_]\w*')

    def proj(z, keep):
        atoms = [x for x in re.sub(r'^\(|\)$', '', z).split(' && ') if x]
        return ' && '.join(sorted(x for x in atoms if keep(x)))

    def count(keep):
        d = collections.defaultdict(set)
        for v, z in vec.values():
            d[v].add(proj(z, keep))
        return sum(len(s) for s in d.values()), max(len(s) for s in d.values()) if d else 0

    def is_cross(x):
        ids = re.findall(r'(SYS|NEG|REF)_\w+', x)
        return bool(diff.match(x)) and len(set(re.findall(r'(SYS|NEG|REF)_', x))) > 1

    def is_diff(x):
        return bool(diff.match(x))
    no_diff = count(lambda x: not is_diff(x))
    no_cross = count(lambda x: not is_cross(x))
    return dict(no_diff=no_diff, no_cross=no_cross, nodes=n, vectors=len(per), max_per_vec=max(per.values()) if per else 0,
                mean_per_vec=round(n / len(per), 2) if per else 0,
                distinct_zone_per_vec_max=max(len(s) for s in zs.values()) if zs else 0,
                edges=nedges, mean_out=round(nedges / n, 2) if n else 0)


recs = {}
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    if l.startswith('#') or not l.strip():
        continue
    p = l.rstrip('\n').split('\t')
    recs[p[0]] = p
with open(OUT, 'w', encoding='utf8') as o:
    hdr = ['id', 'arm', 'nodes', 'vectors', 'max_nodes_per_vector', 'mean_nodes_per_vector',
           'max_distinct_zones_per_vector', 'edges', 'mean_out_degree', 'distinct_without_differences', 'distinct_without_cross_differences', 'reach_stored', 'covreach_stored', 'aLU_covreach_stored']
    o.write('\t'.join(hdr) + '\n')
    for i in ONLY:
        ours = recs[i][2]
        events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
        gv = os.path.join(HERE, 'casaal_out', i + '.gv')
        W = tempfile.mkdtemp()
        try:
            n = re.match(r'R(\d+)$', i).group(1)
            sh([sys.executable, os.path.join(HERE, 'make_resp_system.py'), n, os.path.join(W, 'sys0.xml'), 'badall'])
            sh([sys.executable, os.path.join(HERE, 'tck_normalize_system.py'), os.path.join(W, 'sys0.xml'), os.path.join(W, 'sys.xml')])
            sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'ours'), ours], cwd=W, timeout=LIMIT)
            arms = {'ours': lambda: tp.from_xml('NEG', os.path.join(W, 'ours.xml'))}
            tba = os.path.join(W, 'c.tba')
            rc, _, _ = sh([sys.executable, os.path.join(HERE, 'casaal_to_tba.py'), gv, tba, ','.join(events)])
            if rc == 0:
                rc, _, _ = sh([OPT, '-o', os.path.join(W, 'cexp'), '-n', '0', '-all-copy', tba], timeout=LIMIT)
                if rc == 0:
                    arms['casaal_exp'] = lambda: tp.from_xml('NEG', os.path.join(W, 'cexp.xml'))
            for k in list(arms):
                arms[k + '_dr'] = (lambda m=arms[k]: deadreset(m()))
            for name, mk in arms.items():
                labels = product(events, W, tp.from_xml('SYS', os.path.join(W, 'sys.xml')), mk())
                g = os.path.join(W, 'g.dot')
                if not os.environ.get('SKIP_LIVENESS'):
                    rc, out, err = sh(['timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc', '-l', labels, '-C', 'graph',
                                           '-o', g, os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
                reach = []
                for alg in ('reach', 'covreach', 'aLU-covreach'):
                    rc2, out2, err2 = sh(['timeout', '-s', 'KILL', str(LIMIT), os.path.expanduser('~/local/bin/tck-reach'), '-a', alg,
                                          os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
                    mm = re.search(r'^STORED_STATES (\d+)', out2, re.M)
                    reach.append(mm.group(1) if mm else 'NA')
                if not os.path.exists(g) or os.path.getsize(g) == 0:
                    row = [i, name] + ['NA'] * 9 + reach
                else:
                    r = analyse(g)
                    row = [i, name, r['nodes'], r['vectors'], r['max_per_vec'], r['mean_per_vec'],
                           r['distinct_zone_per_vec_max'], r['edges'], r['mean_out'], r['no_diff'][0], r['no_cross'][0]] + reach
                o.write('\t'.join(map(str, row)) + '\n')
                o.flush()
                print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
