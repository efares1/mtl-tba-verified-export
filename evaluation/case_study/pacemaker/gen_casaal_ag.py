"""CASAAL's automaton for the negation of the assume-guarantee requirement
   (a1 -> <>[<=5] b1) & ... & (ak -> <>[<=5] bk)  ->  [](a1 -> <>[<=5] done)
for k = 2..5 (mutually exclusive events, as in the article).  Writes casaal/agK.gv and casaal/sizes.tsv.
Usage (Windows): python gen_casaal_ag.py [LIMIT_SECONDS]"""
import os, shutil, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..'))
sys.argv, args = sys.argv[:1], sys.argv[1:]
import run_casaal as rc

LIMIT = int(args[0]) if args else 600
OUT = os.path.join(HERE, 'casaal')
os.makedirs(OUT, exist_ok=True)
work = tempfile.mkdtemp()
for f in os.listdir(rc.CASAAL_DIR):
    if f.lower().endswith(('.exe', '.dll')) and os.path.isfile(os.path.join(rc.CASAAL_DIR, f)):
        shutil.copy(os.path.join(rc.CASAAL_DIR, f), work)
rows = [['k', 'status', 'seconds', 'locations', 'transitions', 'clocks']]
for k in (2, 3, 4, 5):
    assume = ' /\\ '.join(f'([](a{i} -> <>[<=5] b{i}))' for i in range(1, k + 1))
    req = f'(({assume}) -> ([](a1 -> <>[<=5] done)))'
    open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive('!(' + req + ')') + '\n')
    dotf = os.path.join(work, 'dot_output.gv')
    if os.path.exists(dotf):
        os.remove(dotf)
    t0 = time.time()
    try:
        subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work, capture_output=True, timeout=LIMIT)
        status = 'ok' if os.path.exists(dotf) else 'no-output'
    except subprocess.TimeoutExpired:
        status = 'timeout'
    sec = time.time() - t0
    if status == 'ok':
        shutil.copy(dotf, os.path.join(OUT, f'ag{k}.gv'))
        n, e, c = rc.count(open(dotf).read())
    else:
        n = e = c = 'NA'
    rows.append([k, status, '%.1f' % sec, n, e, c])
    print(rows[-1], flush=True)
open(os.path.join(OUT, 'sizes.tsv'), 'w').write('\n'.join('\t'.join(map(str, r)) for r in rows) + '\n')
shutil.rmtree(work, ignore_errors=True)
