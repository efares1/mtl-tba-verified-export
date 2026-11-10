"""Effect of the verified export policy and of the optimizer on TChecker.
Four variants of the automaton of the NEGATED requirement, same reference system
(the default optimized, max-delay-exported automaton of the requirement itself):
  opt_maxdelay    optimizer on, maximal-delay split (default)
  opt_allcopy     optimizer on, all-copy split (-all-copy)
  n0_maxdelay     optimizer off (-n 0), maximal-delay split
  n0_allcopy      optimizer off, all-copy split
Workload as in tck_cost_vs_casaal.py (product is empty, whole product explored).
Records sizes (explicit locations, symbolic transitions), diagonal guards in the XML,
stored/visited states, TChecker time and peak memory (kB, /usr/bin/time).
Usage (WSL): python3 tck_export_policy.py [LIMIT_SECONDS] [ID ...]"""
import os, re, subprocess, sys, tempfile, shutil, csv

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.environ.get('TCK', os.path.expanduser('~/local/bin/tck-liveness'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
ONLY = set(sys.argv[2:])
OUT = os.path.join(HERE, os.environ.get('OUTNAME', 'tck_export_policy') + ('_' + os.environ['WORKLOAD'] if os.environ.get('WORKLOAD','ref') != 'ref' else '') + '.tsv' + ('.only' if ONLY else ''))

def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'

HDR = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\t')

def gen(formula, W, base, n=None, allcopy=False):
    args = [EXE, '-nopdf', '-stats', '-o', base]
    if n is not None: args += ['-n', str(n)]
    if allcopy: args += ['-all-copy']
    args += [formula]
    rc, out, err = sh(args, cwd=W, timeout=LIMIT)
    if rc != 0: return None
    d = dict(zip(HDR, out.strip().split('\n')[-1].split('\t')))
    xml = open(os.path.join(W, base + '.xml'), encoding='utf8').read()
    diag = len(re.findall(r'[A-Za-z_][A-Za-z0-9_]*\s*-\s*[A-Za-z_][A-Za-z0-9_]*\s*(?:&lt;|&gt;|<|>|==|!=)', xml))
    return int(d['exp_locs']), int(d['sym_trans']), diag

WORKLOAD = os.environ.get('WORKLOAD', 'ref')
def tck(events, W, neg):
    first = ('REF:' + os.path.join(W, 'ref.xml')) if WORKLOAD == 'ref' else ('SYS:' + os.path.join(W, 'sys.xml'))
    rc, lab, err = sh([sys.executable, os.path.join(HERE, 'tck_product.py'), os.path.join(W, 'm.tck'), events,
                       first, 'NEG:' + neg])
    if rc != 0: return ('convert-error', 'NA', 'NA', 'NA', 'NA')
    rc, out, err = sh(['/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc', '-l', lab.strip(), os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('error' if 'ERROR' in out + err else 'timeout')
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return (verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), g('PEAKKB', err), g('VISITED_TRANSITIONS'))

VARS = [('opt_maxdelay', None, False), ('opt_allcopy', None, True), ('n0_maxdelay', 0, False), ('n0_allcopy', 0, True)]
if os.environ.get('ONLYVARS'): VARS = [v for v in VARS if v[0] in os.environ['ONLYVARS'].split(',')]
done = {r['id'] for r in csv.DictReader(open(os.path.join(HERE, 'tck_cost_vs_casaal.tsv'), encoding='utf8'), delimiter='\t')
        if r['variant'] == 'ours' and r['verdict'] in ('empty', 'nonempty')}
header = ['id', 'variant', 'locs', 'trans', 'diag_guards', 'verdict', 'stored', 'seconds', 'peak_kb', 'visited_trans']
with open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8') as f:
    recs = [l.rstrip('\n').split('\t') for l in f if l.strip() and not l.startswith('#')]
with open(OUT, 'w', encoding='utf8') as o:
    o.write('\t'.join(header) + '\n')
    for rec in recs:
        if len(rec) < 4: continue
        i, desc, ours = rec[0], rec[1], rec[2]
        if (ONLY and i not in ONLY) or (not ONLY and WORKLOAD == 'ref' and i not in done): continue
        events = ','.join(sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'}))
        W = tempfile.mkdtemp()
        try:
            if WORKLOAD == 'ref':
                if gen(ours, W, 'ref', None, os.environ.get('REFPOLICY') == 'allcopy') is None: print(i, 'reference timeout'); continue
            else:
                m = re.match(r'R(\d+)$', i)
                if not m: continue
                sh([sys.executable, os.path.join(HERE, 'make_resp_system.py'), m.group(1), os.path.join(W, 'sys0.xml')] + (['bad'] if WORKLOAD == 'posbad' else []))
                sh([sys.executable, os.path.join(HERE, 'tck_normalize_system.py'), os.path.join(W, 'sys0.xml'), os.path.join(W, 'sys.xml')])
            for name, n, ac in VARS:
                g = gen(('%s' if WORKLOAD == 'posbad' else '!(%s)') % ours, W, 'neg_' + name, n, ac)
                if g is None: row = [i, name, 'NA', 'NA', 'NA', 'tool-timeout', 'NA', 'NA', 'NA', 'NA']
                else:
                    res = tck(events, W, os.path.join(W, 'neg_' + name + '.xml'))
                    row = [i, name, g[0], g[1], g[2], res[0], res[1], res[2], res[3], res[4]]
                o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)
            if True:
                gv = os.path.join(HERE, 'casaal_out' if WORKLOAD == 'posbad' else 'casaal_out_neg', i + '.gv')
                if not os.path.exists(gv): continue
                res = tck(events, W, gv)
                row = [i, 'casaal', 'NA', 'NA', 'NA', res[0], res[1], res[2], res[3], res[4]]
                o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
