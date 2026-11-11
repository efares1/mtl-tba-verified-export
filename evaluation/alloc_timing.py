"""Timing study of the verified clock-reuse pass (mtl2tba -alloc) with TChecker.

For each requirement the negated automaton is generated twice with the same settings, with and without -alloc
(all-copy export, optimizer on), and composed with the positive automaton of the requirement (workload 'ref': the
product is empty and explored completely).  TChecker's Couvreur-based liveness algorithm (tck-liveness -a couvscc) is
run REPS times on each of the two products, alternating the order, on one fixed core.  We record the stored states, the
verdict, TChecker's own running time and the peak resident memory.

Usage (WSL):  python3 alloc_timing.py OUT.tsv LIMIT REPS ITEMS.tsv [pilot]
ITEMS.tsv: id <tab> MTL formula (positive form).  With 'pilot' each product is run once, plain only."""
import os, re, subprocess, sys, tempfile, shutil, statistics, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
CORE = os.environ.get('CORE', '2')
OUT, LIMIT, REPS, ITEMS = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
PILOT = len(sys.argv) > 5 and sys.argv[5] == 'pilot'


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def build(W, name, ref_xml, neg_xml, events):
    first, neg = tp.from_xml('REF', ref_xml), tp.from_xml('NEG', neg_xml)
    labels = ['div']
    for a in (first, neg):
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        if a.state_based and not ls:
            ls = ['acc' + a.name]
            a.locs['unreach'] = (ls, None, False)
        labels += ls
    path = os.path.join(W, name + '.tck')
    tp.write(path, [first, neg], events)
    return path, ','.join(labels), len(neg.clocks)


def run(path, labels):
    t0 = time.time()
    rc, out, err = sh(['taskset', '-c', CORE, '/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT),
                       TCK, '-a', 'couvscc', '-l', labels, path], timeout=LIMIT + 60)
    wall = time.time() - t0
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else 'timeout'
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), g('PEAKKB', err), wall


items = [l.rstrip('\n').split('\t') for l in open(ITEMS, encoding='utf8') if l.strip() and not l.startswith('#')]
hdr = ['id', 'clocks_plain', 'clocks_alloc', 'verdict', 'stored_plain', 'stored_alloc', 'reps',
       'median_s_plain', 'median_s_alloc', 'min_s_plain', 'min_s_alloc', 'ratio_median', 'peak_kb_plain', 'peak_kb_alloc',
       'times_plain', 'times_alloc']
with open(OUT, 'w', encoding='utf8') as o:
    o.write('\t'.join(hdr) + '\n')
    for i, f in items:
        events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)) - {'true', 'false'})
        W = tempfile.mkdtemp()
        try:
            ok = True
            for nm, args, form in (('ref', [], f), ('plain', [], '!(%s)' % f), ('alloc', ['-alloc'], '!(%s)' % f)):
                rc, _, _ = sh([EXE, '-nopdf', '-all-copy'] + args + ['-o', os.path.join(W, nm), form], cwd=W, timeout=300)
                ok = ok and rc == 0
            if not ok:
                print(i, 'generation failed', flush=True)
                continue
            pp, lp, cp = build(W, 'plain', os.path.join(W, 'ref.xml'), os.path.join(W, 'plain.xml'), events)
            pa, la, ca = build(W, 'alloc', os.path.join(W, 'ref.xml'), os.path.join(W, 'alloc.xml'), events)
            if PILOT:
                r = run(pp, lp)
                row = [i, cp, ca, r[0], r[1], 'NA', 1, r[2], 'NA', 'NA', 'NA', 'NA', r[3], 'NA', '', '']
            else:
                tp_, ta_, res = [], [], {}
                for k in range(REPS):
                    order = (('plain', pp, lp), ('alloc', pa, la)) if k % 2 == 0 else (('alloc', pa, la), ('plain', pp, lp))
                    for nm, p, l in order:
                        r = run(p, l)
                        res.setdefault(nm, []).append(r)
                good = all(r[0] in ('empty', 'nonempty') for rs in res.values() for r in rs)
                if not good:
                    row = [i, cp, ca, 'timeout', 'NA', 'NA', REPS] + ['NA'] * 9
                else:
                    sp = {r[1] for r in res['plain']}
                    sa = {r[1] for r in res['alloc']}
                    vp = {r[0] for r in res['plain']} | {r[0] for r in res['alloc']}
                    tpl = [float(r[2]) for r in res['plain']]
                    tal = [float(r[2]) for r in res['alloc']]
                    row = [i, cp, ca, '/'.join(sorted(vp)), '/'.join(sorted(sp)), '/'.join(sorted(sa)), REPS,
                           '%.4f' % statistics.median(tpl), '%.4f' % statistics.median(tal), '%.4f' % min(tpl), '%.4f' % min(tal),
                           '%.3f' % (statistics.median(tal) / statistics.median(tpl)),
                           statistics.median([int(r[3]) for r in res['plain']]), statistics.median([int(r[3]) for r in res['alloc']]),
                           ','.join('%.3f' % x for x in tpl), ','.join('%.3f' % x for x in tal)]
            o.write('\t'.join(map(str, row)) + '\n')
            o.flush()
            print('\t'.join(map(str, row[:14])), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
