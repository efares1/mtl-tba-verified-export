"""Survey of dominated-transition pruning in the tool (mtl2tba -prune and -prune-split, all-copy export): locations and
transitions of the exported automaton and whether the checker accepted the certificate, for the benchmark patterns
(evaluation/formulas.tsv) and the 100 random formulas (random_formulas_4col.tsv), in both polarities.

Usage (WSL): EXE=path/to/mtl2tba.exe python3 prune_survey.py OUT.tsv"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
COLS = ['formula_clocks', 'spot_states', 'spot_trans', 'spot_s', 'comp_locs', 'comp_trans', 'comp_clocks', 'opt_rounds',
        'opt_locs', 'opt_trans', 'opt_clocks', 'exp_locs', 'exp_trans', 'exp_clocks', 'exp_invs', 'exp_diffs', 'opt_s',
        'exp_s', 'total_s', 'init_free', 'sym_trans']
VARIANTS = (('plain', []), ('prune', ['-prune']), ('split', ['-prune-split']))


def run(form, flags, W):
    cmd = [EXE, '-nopdf', '-stats', '-v', '-all-copy'] + flags + ['-o', os.path.join(W, 'o'), form]
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
        o.write('id\tset\tpolarity\tvariant\topt_trans\texp_locs\texp_trans\texp_diffs\taccepted\n')
        for i, st, f in items:
            for pol, form in (('pos', f), ('neg', '!(%s)' % f)):
                for name, flags in VARIANTS:
                    a, acc = run(form, flags, W)
                    if a is None:
                        row = [i, st, pol, name] + ['NA'] * 5
                    else:
                        row = [i, st, pol, name, a['opt_trans'], a['exp_locs'], a['exp_trans'], a['exp_diffs'], acc]
                    o.write('\t'.join(row) + '\n')
                o.flush()
finally:
    shutil.rmtree(W, ignore_errors=True)
