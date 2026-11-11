"""Dominated-transition pruning (with splitting by cells of letters) on the TBAs of run_independent.py.

Reuses the corpus and the canonical inputs written by run_independent.py (inside WSL, ~/mut/independent), runs the
unmutated tba_opt of the repository (tool/src, built as ~/mut/exe/jss_tba_opt.exe) with -prune-split and the two
variants, and compares the exported XML with the input by the bounded word test lang_cmp (WORDS words, 60 loop
iterations).  Also records whether the checker accepted the certificate and the sizes after the optimizer and the pruning.
Usage (WSL): python3 run_independent_prune.py [WORDS]
Writes results/independent_prune.tsv and results/independent_prune_summary.txt."""
import os, sys, glob, re, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'mutation'))
import to_canon
from mut_lib import sh, events_of, HOME

LC = HOME + '/mut/exe/lang_cmp_new'
os.environ['LANGCMP_EXTRA'] = os.environ.get('LANGCMP_EXTRA', '60')
EXE = HOME + '/mut/exe/jss_tba_opt.exe'
WORK = HOME + '/mut/independent'
CORP = WORK + '/corpus'
OUT = WORK + '/outp'
WORDS = sys.argv[1] if len(sys.argv) > 1 else '20000'
os.makedirs(OUT, exist_ok=True)
rows = []
for p in sorted(glob.glob(CORP + '/*.tba')):
    name = os.path.basename(p)[:-4]
    evs = events_of(p)
    a = WORK + '/out/' + name + '.in.can'
    # sizes without pruning: optimizer only
    rc0, so0, se0 = sh([EXE, '-o', OUT + '/' + name + '.n', '-stats', p], timeout=60)
    f0 = so0.split('\t')
    for pol, flags in (('pr', ['-prune']), ('ps', ['-prune-split'])):
        base = OUT + '/' + name + '.' + pol
        rc, so, se = sh([EXE, '-o', base, '-stats'] + flags + [p], timeout=120)
        f = so.strip().split('\t')
        ok = 'accepted by the checker: true' in se
        mm = ''
        if rc == 0 and os.path.exists(base + '.xml'):
            b = base + '.can'
            try:
                to_canon.from_xml(base + '.xml', evs, b)
                r2, o2, e2 = sh([LC, a, b, WORDS, '31'], timeout=900)
                m = re.search(r'mismatch=(\d+)', o2)
                mm = int(m.group(1)) if m else -1
            except Exception:
                mm = -2
        rows.append(dict(name=name, pol=pol, rc=rc, accepted=int(ok), t_opt=f0[5] if len(f0) > 5 else '', t_prune=f[5] if len(f) > 5 else '',
                         s_opt=f0[4] if len(f0) > 4 else '', s_prune=f[4] if len(f) > 4 else '', mm=mm))
cols = ['name', 'pol', 'rc', 'accepted', 's_opt', 't_opt', 's_prune', 't_prune', 'mm']
os.makedirs(HERE + '/results', exist_ok=True)
with open(HERE + '/results/independent_prune.tsv', 'w') as fh:
    fh.write('\t'.join(cols) + '\n')
    for r in rows:
        fh.write('\t'.join(str(r[c]) for c in cols) + '\n')
L = []
for fam in ('graph', 'monitor'):
    for pol in ('pr', 'ps'):
        R = [r for r in rows if r['name'].startswith(fam) and r['pol'] == pol and r['rc'] == 0]
        t0 = sum(int(r['t_opt']) for r in R); t1 = sum(int(r['t_prune']) for r in R)
        red = sum(1 for r in R if int(r['t_prune']) < int(r['t_opt']))
        mm = sum(1 for r in R if r['mm'] not in ('', 0))
        rej = sum(1 for r in R if not r['accepted'])
        L.append('%s %s: %d inputs ok, certificate rejected %d, language mismatches %d, transitions after the optimizer %d -> after pruning %d, inputs with fewer transitions %d'
                 % (fam, 'prune' if pol == 'pr' else 'prune-split', len(R), rej, mm, t0, t1, red))
open(HERE + '/results/independent_prune_summary.txt', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L))
