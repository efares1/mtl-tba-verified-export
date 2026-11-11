"""Survey of the clock-reuse pass in the tool (mtl2tba -alloc, all-copy export): clocks of the exported automaton,
locations and transitions, and whether the checker accepted the certificate, for the benchmark patterns
(evaluation/formulas.tsv) and the 100 random formulas (random_formulas_4col.tsv), in both polarities.

Usage (WSL): python3 alloc_survey.py OUT.tsv"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
COLS = ['formula_clocks', 'spot_states', 'spot_trans', 'spot_s', 'comp_locs', 'comp_trans', 'comp_clocks', 'opt_rounds',
        'opt_locs', 'opt_trans', 'opt_clocks', 'exp_locs', 'exp_trans', 'exp_clocks', 'exp_invs', 'exp_diffs', 'opt_s',
        'exp_s', 'total_s', 'init_free', 'sym_trans']


def run(form, alloc, W):
    cmd = [EXE, '-nopdf', '-stats', '-v', '-all-copy'] + (['-alloc'] if alloc else []) + ['-o', os.path.join(W, 'o'), form]
    try:
        r = subprocess.run(cmd, cwd=W, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return None, None
    if r.returncode:
        return None, None
    line = [l for l in r.stdout.strip().split('\n') if re.match(r'^[\d.\t]+$', l.strip())]
    vals = dict(zip(COLS, line[-1].split('\t'))) if line else None
    acc = re.search(r'certificate accepted by the checker: (\w+)', r.stderr + r.stdout)
    return vals, (acc.group(1) if acc else 'NA')


items = []
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    if l.strip() and not l.startswith('#'):
        p = l.rstrip('\n').split('\t')
        items.append((p[0], 'benchmark', p[2]))
for l in open(os.path.join(HERE, 'random_formulas_4col.tsv'), encoding='utf8'):
    if l.strip() and not l.startswith('#'):
        p = l.rstrip('\n').split('\t')
        items.append((p[0], 'random', p[2]))
W = tempfile.mkdtemp()
try:
    with open(sys.argv[1], 'w', encoding='utf8') as o:
        o.write('id\tset\tpolarity\tclocks_plain\tclocks_alloc\topt_clocks_plain\topt_clocks_alloc\tlocs_plain\tlocs_alloc\ttrans_plain\ttrans_alloc\taccepted\n')
        for i, st, f in items:
            for pol, form in (('pos', f), ('neg', '!(%s)' % f)):
                a, _ = run(form, False, W)
                b, acc = run(form, True, W)
                if a is None or b is None:
                    row = [i, st, pol] + ['NA'] * 9
                else:
                    row = [i, st, pol, a['exp_clocks'], b['exp_clocks'], a['opt_clocks'], b['opt_clocks'], a['exp_locs'], b['exp_locs'],
                           a['exp_trans'], b['exp_trans'], acc]
                o.write('\t'.join(row) + '\n')
finally:
    shutil.rmtree(W, ignore_errors=True)
