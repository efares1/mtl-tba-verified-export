"""Model-checking cost of the automaton of the NEGATED requirement, three variants:
  ours      mtl2tba with optimization (default) and export
  ours_n0   mtl2tba with -n 0 (no optimization; export still applied)
  casaal    CASAAL's automaton of the negation (casaal_out_neg/<id>.gv)
Workload ('ref'): the reference system is mtl2tba's optimized automaton for the
requirement itself (accepting exactly the requirement's words, used as a Buechi
component), composed with the variant automaton of the negation.  The product is
empty when everything is correct, so TChecker (tck-liveness, couvscc) explores the
whole product: stored states do not depend on the search order.  The same reference
system is used for the three variants.
Also records sizes of the three negated automata (locations, symbolic transitions).
Usage (WSL): python3 tck_cost_vs_casaal.py [LIMIT_SECONDS] [ID ...]
Writes tck_cost_vs_casaal.tsv."""
import os, re, subprocess, sys, tempfile, csv, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.environ.get('TCK', os.path.expanduser('~/local/bin/tck-liveness'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
ONLY = set(sys.argv[2:])
OUT = os.path.join(HERE, 'tck_cost_vs_casaal.tsv' + ('.only' if ONLY else ''))

def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'

def stats(formula, n, W, base):
    args = [EXE, '-nopdf', '-stats', '-o', base, formula]
    if n is not None:
        args[1:1] = ['-n', str(n)]
    rc, out, err = sh(args, cwd=W, timeout=LIMIT)
    if rc != 0:
        return None
    h = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\t')
    row = out.strip().split('\n')[-1].split('\t')
    d = dict(zip(h, row))
    return int(d['exp_locs']), int(d['sym_trans'])

def casaal_size(path):
    txt = open(path, encoding='utf8').read()
    states, edges = set(), 0
    for m in re.finditer(r'^\s*(\w+)\s*->\s*(\w+)\s*(?:\[label="(.*?)"\])?\s*$', txt, re.M | re.S):
        a, b = m.group(1), m.group(2)
        if a == '0':
            continue
        states |= {a, b}; edges += 1
    return len(states), edges

def tck(events, W, args):
    rc, lab, err = sh([sys.executable, os.path.join(HERE, 'tck_product.py'), os.path.join(W, 'm.tck'), events] + args)
    if rc != 0:
        return ('convert-error', 'NA', 'NA', 'NA', 'NA')
    labels = lab.strip()
    rc, out, err = sh([TCK, '-a', 'couvscc', '-l', labels, os.path.join(W, 'm.tck')], timeout=LIMIT)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else 'timeout'
    g = lambda k: (re.search(r'^%s (\S+)' % k, out, re.M) or [None, 'NA'])[1]
    return (verdict, g('STORED_STATES'), g('VISITED_STATES'), g('VISITED_TRANSITIONS'), g('RUNNING_TIME_SECONDS'))

rows = []
header = ['id', 'variant', 'locs', 'trans', 'verdict', 'stored', 'visited', 'visited_trans', 'seconds']
with open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8') as f:
    lines = [l.rstrip('\n').split('\t') for l in f if l.strip() and not l.startswith('#')]
with open(OUT, 'w', encoding='utf8') as o:
    o.write('\t'.join(header) + '\n')
    for rec in lines:
        if len(rec) < 4:
            continue
        i, desc, ours, cas = rec[:4]
        if ONLY and i not in ONLY:
            continue
        if cas.startswith('~') or cas == '-' or not cas:
            continue
        gv = os.path.join(HERE, 'casaal_out_neg', i + '.gv')
        if not os.path.exists(gv):
            continue
        events = ','.join(sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'}))
        W = tempfile.mkdtemp()
        try:
            refsz = stats(ours, None, W, 'ref')
            vars_ = {}
            vars_['ours'] = stats('!(%s)' % ours, None, W, 'neg_opt')
            vars_['ours_n0'] = stats('!(%s)' % ours, 0, W, 'neg_n0')
            if refsz is None:
                print(i, 'reference timeout'); continue
            for var, sz in vars_.items():
                if sz is None:
                    row = [i, var, 'NA', 'NA', 'tool-timeout', 'NA', 'NA', 'NA', 'NA']
                else:
                    base = 'neg_opt' if var == 'ours' else 'neg_n0'
                    res = tck(events, W, ['REF:' + os.path.join(W, 'ref.xml'), 'NEG:' + os.path.join(W, base + '.xml')])
                    row = [i, var, sz[0], sz[1]] + list(res)
                o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)
            cs = casaal_size(gv)
            res = tck(events, W, ['REF:' + os.path.join(W, 'ref.xml'), 'NEG:' + gv])
            row = [i, 'casaal', cs[0], cs[1]] + list(res)
            o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
