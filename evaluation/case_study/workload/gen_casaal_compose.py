"""CASAAL automata for the assumption automata A_k = /\_i [](a_i -> <>[<=3] b_i) (positive form) and for the negated
guarantee N = !([](a1 -> <>[<=5] done)); events exclusive.  Writes casaal/A<k>.gv, casaal/N.gv, casaal/sizes_compose.tsv.
Usage (Windows): python gen_casaal_compose.py [LIMIT_SECONDS]"""
import os, shutil, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..'))
sys.argv, args = sys.argv[:1], sys.argv[1:]
import run_casaal as rc
LIMIT = int(args[0]) if args else 600
OUT = os.path.join(HERE, 'casaal'); os.makedirs(OUT, exist_ok=True)
AND = ' /' + chr(92) + ' '
work = tempfile.mkdtemp()
for f in os.listdir(rc.CASAAL_DIR):
    if f.lower().endswith(('.exe', '.dll')) and os.path.isfile(os.path.join(rc.CASAAL_DIR, f)):
        shutil.copy(os.path.join(rc.CASAAL_DIR, f), work)
jobs = [('N', '!([](a1 -> <>[<=5] done))')]
for k in (2, 3, 4, 5):
    jobs.append((f'A{k}', AND.join(f'([](a{i} -> <>[<=3] b{i}))' for i in range(1, k + 1))))
rows = [['name', 'status', 'seconds', 'locations', 'transitions', 'clocks']]
for name, f in jobs:
    open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive(f) + '\n')
    dotf = os.path.join(work, 'dot_output.gv')
    if os.path.exists(dotf):
        os.remove(dotf)
    t0 = time.time()
    try:
        subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work, capture_output=True, timeout=LIMIT)
        st = 'ok' if os.path.exists(dotf) else 'no-output'
    except subprocess.TimeoutExpired:
        st = 'timeout'
    sec = time.time() - t0
    if st == 'ok':
        shutil.copy(dotf, os.path.join(OUT, f'{name}.gv')); n, e, c = rc.count(open(dotf).read())
    else:
        n = e = c = 'NA'
    rows.append([name, st, '%.1f' % sec, n, e, c]); print(rows[-1], flush=True)
open(os.path.join(OUT, 'sizes_compose.tsv'), 'w').write('\n'.join('\t'.join(map(str, r)) for r in rows) + '\n')
shutil.rmtree(work, ignore_errors=True)
