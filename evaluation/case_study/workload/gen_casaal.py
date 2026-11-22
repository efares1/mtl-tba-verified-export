"""CASAAL automata (casaal/<family><k>_<variant>.gv) of the negated requirements of reqs.py.
Usage (Windows): python gen_casaal.py [LIMIT_SECONDS]   Writes casaal/sizes.tsv."""
import os, shutil, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..')); sys.path.insert(0, HERE)
sys.argv, args = sys.argv[:1], sys.argv[1:]
import run_casaal as rc, reqs
LIMIT = int(args[0]) if args else 600
OUT = os.path.join(HERE, 'casaal'); os.makedirs(OUT, exist_ok=True)
work = tempfile.mkdtemp()
for f in os.listdir(rc.CASAAL_DIR):
    if f.lower().endswith(('.exe', '.dll')) and os.path.isfile(os.path.join(rc.CASAAL_DIR, f)):
        shutil.copy(os.path.join(rc.CASAAL_DIR, f), work)
rows = [['family', 'k', 'variant', 'status', 'seconds', 'locations', 'transitions', 'clocks']]
done = {}
for fam, k in reqs.ALL:
    for var in ('ok', 'bad'):
        cas = reqs.build(fam, k, var)[1]
        key = (fam, k, cas)
        if key in done:
            shutil.copy(os.path.join(OUT, f'{fam}{k}_{done[key]}.gv'), os.path.join(OUT, f'{fam}{k}_{var}.gv'))
            continue
        open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive(cas) + '\n')
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
            shutil.copy(dotf, os.path.join(OUT, f'{fam}{k}_{var}.gv'))
            n, e, c = rc.count(open(dotf).read())
            done[key] = var
        else:
            n = e = c = 'NA'
        rows.append([fam, k, var, st, '%.1f' % sec, n, e, c])
        print(rows[-1], flush=True)
open(os.path.join(OUT, 'sizes.tsv'), 'w').write('\n'.join('\t'.join(map(str, r)) for r in rows) + '\n')
shutil.rmtree(work, ignore_errors=True)
