"""Prototype (unverified) of liveness-based clock allocation, to measure what it would buy before any proof.

The negated automaton exported by mtl2tba (all-copy) is read back, the clocks are coloured by the
interference graph of clock_liveness.py, and clocks of one colour are renamed to one clock.  The
renamed automaton is composed with the same systems as in baselines/run_baselines.py and given to
tck-liveness.  We report clocks, stored states and time before and after, and whether the verdicts agree.
Verdict agreement on the systems is a sanity check of the prototype, not a proof: the pass would have
to be proved in Rocq as a language-preserving transformation.

With VERIFIED=1 the 'after' automaton is the one mtl2tba -alloc exports (Coq: alloc_pass), not this renaming.
Usage (WSL): python3 alloc_probe.py OUT.tsv ID...      (ids Rn of formulas.tsv, plus F-ids for the ref workload)
"""
import os, re, subprocess, sys, tempfile, shutil, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp
spec = importlib.util.spec_from_file_location('cl', os.path.join(HERE, 'clock_liveness_lib.py'))
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)

OUT = sys.argv[1]
ONLY = sys.argv[2:]
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
LIMIT = int(os.environ.get('LIMIT', '200'))
VERIFIED = os.environ.get('VERIFIED') == '1'   # use mtl2tba -alloc (verified checker) instead of the unverified renaming below


def sh(cmd, cwd=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=LIMIT + 30)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def allocate(a):
    col = cl.colouring(a)
    if not col:
        return a, 0
    rep = {}
    for c, k in col.items():
        rep.setdefault(k, c)
    ren = {c: rep[k] for c, k in col.items()}
    pat = re.compile(r'\b' + a.name + r'_x\d+\b')
    sub = lambda s: pat.sub(lambda m: ren.get(m.group(0), m.group(0)), s) if s else s
    b = tp.Auto(a.name)
    b.state_based = a.state_based
    b.init = a.init
    for l, (lab, inv, com) in a.locs.items():
        b.locs[l] = (lab, sub(inv), com)
    for (s, t, ev, g, rs, lab) in a.edges:
        b.edges.append((s, t, ev, sub(g), sorted({ren[r] for r in rs}), lab))
    b.clocks = {rep[k][len(a.name) + 1:] for k in rep}
    return b, len(rep)


def clock_names(a):
    return len(a.clocks)


def stored(W, events, first, neg):
    # a clock set shared by processes must be declared once; the parser records raw names, write() adds the prefix
    autos = [first, neg]
    labels = ['div']
    for a in autos:
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        if a.state_based and not ls:
            ls = ['acc' + a.name]
            a.locs['unreach'] = (ls, None, False)
        labels += ls
    tp.write(os.path.join(W, 'm.tck'), autos, events)
    rc, out, err = sh(['/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc', '-l',
                       ','.join(labels), os.path.join(W, 'm.tck')])
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('error' if 'ERROR' in out + err else 'timeout')
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS')


recs = {}
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    if l.startswith('#') or not l.strip():
        continue
    p = l.rstrip('\n').split('\t')
    recs[p[0]] = p[2]
W = tempfile.mkdtemp()
try:
    with open(OUT, 'w', encoding='utf8') as o:
        o.write('id\tworkload\tclocks\tclocks_alloc\tverdict\tverdict_alloc\tstored\tstored_alloc\tseconds\tseconds_alloc\n')
        for i in ONLY:
            f = recs[i]
            events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)) - {'true', 'false'})
            rc, _, _ = sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'neg'), '!(%s)' % f], cwd=W)
            if rc:
                continue
            neg = tp.from_xml('NEG', os.path.join(W, 'neg.xml'))
            if VERIFIED:
                sh([EXE, '-alloc', '-nopdf', '-all-copy', '-o', os.path.join(W, 'negv'), '!(%s)' % f], cwd=W)
            al, ncol = allocate(tp.from_xml('NEG', os.path.join(W, 'neg.xml')))
            works = {}
            sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'ref'), f], cwd=W)
            works['ref'] = lambda: tp.from_xml('REF', os.path.join(W, 'ref.xml'))
            m = re.match(r'R(\d+)$', i)
            if m:
                for kind in ('ok', 'bad'):
                    sh([sys.executable, os.path.join(HERE, 'make_resp_system.py'), m.group(1), os.path.join(W, 'sys0%s.xml' % kind)]
                       + (['bad'] if kind == 'bad' else []))
                    sh([sys.executable, os.path.join(HERE, 'tck_normalize_system.py'), os.path.join(W, 'sys0%s.xml' % kind),
                        os.path.join(W, 'sys%s.xml' % kind)])
                    works['resp_' + kind] = (lambda k=kind: tp.from_xml('SYS', os.path.join(W, 'sys%s.xml' % k)))
            for w, mk in works.items():
                v1, s1, t1 = stored(W, events, mk(), tp.from_xml('NEG', os.path.join(W, 'neg.xml')))
                al2 = tp.from_xml('NEG', os.path.join(W, 'negv.xml')) if VERIFIED else allocate(tp.from_xml('NEG', os.path.join(W, 'neg.xml')))[0]
                v2, s2, t2 = stored(W, events, mk(), al2)
                row = [i, w, len(neg.clocks), len(al2.clocks), v1, v2, s1, s2, t1, t2]
                o.write('\t'.join(map(str, row)) + '\n')
                o.flush()
                print('\t'.join(map(str, row)), flush=True)
finally:
    shutil.rmtree(W, ignore_errors=True)
