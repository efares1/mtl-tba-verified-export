"""CASAAL's automaton of the negated requirement, then our verified optimizer.
For every pattern with a CASAAL automaton (casaal_out_neg/<id>.gv, one acceptance set):
  - sizes: CASAAL as imported (locations/transitions after the conversion to location
    acceptance), after the optimizer (-n default), exported (explicit transitions,
    symbolic transitions, diagonal guards), also with -n 0 and with -all-copy;
  - for the patterns whose product TChecker completes: stored states and verdict of the
    product with the reference system, for CASAAL's original automaton, its import without
    optimization (-n 0), and its import with optimization.
Usage (WSL): python3 casaal_then_optimizer.py [LIMIT_SECONDS] [ID ...]"""
import os, re, subprocess, sys, tempfile, shutil, csv

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OPT = os.environ.get('OPT', os.path.expanduser('~/tool_copy/_build/default/src/tba_opt.exe'))
TCK = os.environ.get('TCK', os.path.expanduser('~/local/bin/tck-liveness'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
ONLY = set(sys.argv[2:])
OUT = os.path.join(HERE, 'casaal_then_optimizer.tsv' + ('.only' if ONLY else ''))

def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'

def tck(events, W, neg):
    rc, lab, err = sh([sys.executable, os.path.join(HERE, 'tck_product.py'), os.path.join(W, 'm.tck'), events,
                       'REF:' + os.path.join(W, 'ref.xml'), 'NEG:' + neg])
    if rc != 0: return ('convert-error', 'NA', 'NA', 'NA')
    rc, out, err = sh(['/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc', '-l', lab.strip(), os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('error' if 'ERROR' in out + err else 'timeout')
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return (verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), g('PEAKKB', err))

done = {r['id'] for r in csv.DictReader(open(os.path.join(HERE, 'tck_cost_vs_casaal.tsv'), encoding='utf8'), delimiter='\t')
        if r['variant'] == 'casaal' and r['verdict'] in ('empty', 'nonempty')}
header = ['id', 'imp_locs', 'imp_trans', 'opt_rounds', 'opt_locs', 'opt_trans',
          'exp_locs_n0', 'exp_trans_n0', 'sym_n0', 'exp_locs', 'exp_trans', 'sym', 'diag', 'sym_allcopy', 'init_free',
          'tck_orig', 'tck_n0', 'tck_opt']
with open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8') as f:
    recs = [l.rstrip('\n').split('\t') for l in f if l.strip() and not l.startswith('#')]
with open(OUT, 'w', encoding='utf8') as o:
    o.write('\t'.join(header) + '\n')
    for rec in recs:
        if len(rec) < 4: continue
        i, desc, ours, cas = rec[:4]
        if ONLY and i not in ONLY: continue
        if cas.startswith('~') or cas == '-' or not cas: continue
        gv = os.path.join(HERE, 'casaal_out_neg', i + '.gv')
        if not os.path.exists(gv): continue
        events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
        W = tempfile.mkdtemp()
        try:
            tba = os.path.join(W, 'c.tba')
            rc, _, _ = sh([sys.executable, os.path.join(HERE, 'casaal_to_tba.py'), gv, tba, ','.join(events)])
            if rc != 0:
                print(i, 'not converted (rc %d)' % rc); continue
            def run(args, base):
                rc, out, err = sh([OPT, '-stats', '-o', os.path.join(W, base)] + args + [tba], timeout=LIMIT)
                return None if rc != 0 else list(map(int, out.strip().split('\n')[-1].split('\t')))
            a = run([], 'opt'); b = run(['-n', '0'], 'n0'); c = run(['-all-copy'], 'ac')
            if not (a and b and c):
                print(i, 'tba_opt failed/timeout'); continue
            # fields: s0 t0 c0 k s1 t1 c1 locs dtrs ndiff sym free
            row = [i, a[0], a[1], a[3], a[4], a[5], b[7], b[8], b[10], a[7], a[8], a[10], a[9], c[10], a[11]]
            res = ['NA', 'NA', 'NA']
            if i in done or i in ONLY:
                rc, _, _ = sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'ref'), ours], cwd=W, timeout=LIMIT)
                if rc == 0:
                    ev = ','.join(events)
                    r1 = tck(ev, W, gv); r2 = tck(ev, W, os.path.join(W, 'n0.xml')); r3 = tck(ev, W, os.path.join(W, 'opt.xml'))
                    res = ['%s/%s/%ss/%skB' % r for r in (r1, r2, r3)]
            row += res
            o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
