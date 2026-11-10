r"""Generation time of CASAAL on the negation of every formula with an exact CASAAL encoding
(the same input as run_casaal_neg.py).  Works in a scratch folder; casaal_out_neg is untouched.
    python casaal_time.py [LIMIT_SECONDS] [REPS] [ID ...]
Writes casaal_time.tsv: id, status, best_seconds, all_seconds."""
import os, shutil, subprocess, sys, tempfile, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.argv, args = sys.argv[:1], sys.argv[1:]          # run_casaal reads sys.argv itself
import run_casaal as rc

HERE = os.path.dirname(os.path.abspath(__file__))
LIMIT = int(args[0]) if args else 900
REPS = int(args[1]) if len(args) > 1 else 3
ONLY = set(args[2:])
cdir = rc.CASAAL_DIR

work = tempfile.mkdtemp()
for f in os.listdir(cdir):
    if f.lower().endswith(('.exe', '.dll')) and os.path.isfile(os.path.join(cdir, f)):
        shutil.copy(os.path.join(cdir, f), work)

with open(os.path.join(HERE, 'casaal_time.tsv'), 'w') as o:
    o.write('id\tstatus\tbest_s\tall_s\n')
    for fid, desc, ours, cas in rc.formulas():
        if cas == '-' or cas.startswith('~') or (ONLY and fid not in ONLY):
            continue
        open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive('!(' + cas + ')') + '\n')
        times, status = [], 'ok'
        for _ in range(REPS):
            dotf = os.path.join(work, 'dot_output.gv')
            if os.path.exists(dotf):
                os.remove(dotf)
            t0 = time.time()
            try:
                subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work,
                               capture_output=True, timeout=LIMIT)
            except subprocess.TimeoutExpired:
                status = 'timeout'; times.append(float(LIMIT)); break
            times.append(time.time() - t0)
            if not os.path.exists(dotf):
                status = 'no-output'
            if times[-1] > 20:       # slow case: one repetition is enough
                break
        row = [fid, status, '%.2f' % min(times), ' '.join('%.2f' % t for t in times)]
        o.write('\t'.join(row) + '\n'); o.flush(); print('\t'.join(row), flush=True)
shutil.rmtree(work, ignore_errors=True)
