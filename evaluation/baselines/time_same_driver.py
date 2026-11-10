"""Generation time of mtl2tba (WSL) and CASAAL (Windows exe launched from WSL) measured by
ONE driver with the SAME number of repetitions, reporting median, min and max.
CASAAL has no Linux build, so the two tools still run on different OS kernels; the driver
and the wall-clock method are identical.  Also times a trivial CASAAL run to estimate the
process-start overhead of the interop launch.
Usage (WSL, machine otherwise idle): python3 time_same_driver.py REPS LIMIT ID...
Writes timing_same_driver.tsv."""
import itertools, os, re, shutil, statistics, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, '..')
EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
CAS_SRC = os.environ.get('CASAAL_DIR', '/mnt/c/Users/user/Desktop/casaal/casaal')
REPS = int(sys.argv[1]); LIMIT = int(sys.argv[2]); IDS = sys.argv[3:]


def exclusive(f):
    props = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)))
    pairs = ['([](!(%s /\\ %s)))' % (a, b) for a, b in itertools.combinations(props, 2)]
    return ' /\\ '.join(['(%s)' % f] + pairs) if pairs else f


def timed(cmd, cwd):
    t0 = time.perf_counter()
    try:
        subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=LIMIT)
    except subprocess.TimeoutExpired:
        return None
    return time.perf_counter() - t0


work = tempfile.mkdtemp(dir='/mnt/c/Users/user/.claude/jobs/d3cb801e/tmp')
for f in os.listdir(CAS_SRC):
    if f.lower().endswith(('.exe', '.dll')):
        shutil.copy(os.path.join(CAS_SRC, f), work)
recs = {}
for l in open(os.path.join(EV, 'formulas.tsv'), encoding='utf8'):
    if l.startswith('#') or not l.strip():
        continue
    p = l.rstrip('\n').split('\t')
    recs[p[0]] = p
rows = []
with open(os.path.join(HERE, 'timing_same_driver.tsv'), 'w') as o:
    o.write('id\ttool\treps\tmedian_s\tmin_s\tmax_s\tall_s\n')

    def emit(i, tool, ts):
        ok = [t for t in ts if t is not None]
        if not ok:
            row = [i, tool, len(ts), 'timeout', '', '', '']
        else:
            row = [i, tool, len(ts), '%.3f' % statistics.median(ok), '%.3f' % min(ok), '%.3f' % max(ok),
                   ' '.join('%.3f' % t for t in ok)]
        o.write('\t'.join(map(str, row)) + '\n'); o.flush(); print('\t'.join(map(str, row)), flush=True)

    # process-start overhead of the interop launch (CASAAL on a trivial formula)
    open(os.path.join(work, 'f.txt'), 'w').write('[]p\n')
    emit('trivial', 'casaal', [timed([os.path.join(work, 'casaal.exe'), 'f.txt'], work) for _ in range(REPS)])
    for i in IDS:
        if i not in recs or recs[i][3] in ('-',) or recs[i][3].startswith('~'):
            continue
        ours, cas = recs[i][2], recs[i][3]
        open(os.path.join(work, 'f.txt'), 'w').write(exclusive('!(' + cas + ')') + '\n')
        w2 = tempfile.mkdtemp()
        for tool in ('ours', 'casaal'):
            ts = []
            for k in range(REPS):
                if tool == 'ours':
                    t = timed([EXE, '-nopdf', '-o', os.path.join(w2, 'o'), '!(%s)' % ours], w2)
                else:
                    df = os.path.join(work, 'dot_output.gv')
                    if os.path.exists(df):
                        os.remove(df)
                    t = timed([os.path.join(work, 'casaal.exe'), 'f.txt'], work)
                ts.append(t)
                if t is None or t > 60:
                    break
            emit(i, tool, ts)
        shutil.rmtree(w2, ignore_errors=True)
shutil.rmtree(work, ignore_errors=True)
