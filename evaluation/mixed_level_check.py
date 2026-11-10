"""Mixed deep/wide formulas (not in the benchmark) and the two Spot settings on
their negation.  Writes mixed_level_check.tsv.  usage: mixed_level_check.py [limit]"""
import subprocess, sys, time, os, itertools
D = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(D, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
LIM = int(sys.argv[1]) if len(sys.argv) > 1 else 30

def chain_f(d, k):   # nested eventualities
    s = 'p%d_%d' % (k, d)
    for j in range(d - 1, 0, -1):
        s = '<>[<=5](p%d_%d & %s)' % (k, j, s) if j < d else s
    return '<>[<=5](p%d_1 & %s)' % (k, s) if d > 1 else '<>[<=5] p%d_1' % k
def nest(d, k):
    s = 'p%d_%d' % (k, d)
    for j in range(d - 1, 0, -1):
        s = '<>[<=5](p%d_%d & %s)' % (k, j, s)
    return '<>[<=5] ' + s if d == 1 else s
def resp(k): return '[](a%d -> <>[<=5] b%d)' % (k, k)
def ginv(d, k):   # nested bounded invariance
    s = 'q%d_%d' % (k, d)
    for j in range(d - 1, 0, -1):
        s = '[][<=5](q%d_%d -> %s)' % (k, j, s)
    return '[][<=5] ' + s if d == 1 else s

cases = []
for d, w in itertools.product([2, 4, 5, 6], [1, 2, 3]):
    cases.append(('nest d%d w%d' % (d, w), d, w, ' & '.join(nest(d, k) for k in range(w))))
for d, w in [(5, 2), (6, 2), (3, 3), (5, 3)]:
    cases.append(('inv d%d w%d' % (d, w), d, w, ' & '.join(ginv(d, k) for k in range(w))))
for d, r in [(2, 4), (3, 4), (5, 3), (6, 3), (3, 6), (5, 5)]:
    cases.append(('nest d%d + %d resp' % (d, r), d, r + 1, nest(d, 0) + ' & ' + ' & '.join(resp(k) for k in range(1, r + 1))))

def run(f, opts):
    t = time.time()
    try:
        r = subprocess.run([EXE, '-nopdf', '-stats'] + opts + ['-o', os.devnull + '_x' if False else 'mc_tmp', '!(' + f + ')'],
                           capture_output=True, text=True, timeout=LIM, cwd=os.environ.get('TMPDIR', '/tmp'))
        ok = r.returncode == 0 and r.stdout.strip() != ''
    except subprocess.TimeoutExpired:
        ok = False
    return ('%.1fs' % (time.time() - t)) if ok else ('>%ds' % LIM)

with open(os.path.join(D, 'mixed_level_check.tsv'), 'w') as out:
    out.write('case\tdepth\twidth\tneg_low\tneg_any\n')
    for name, d, w, f in cases:
        lo, an = run(f, ['-spot-level', 'low']), run(f, ['-simp', '-spot-level', 'any', '-spot-x', 'ba-simul=0'])
        out.write('%s\t%d\t%d\t%s\t%s\n' % (name, d, w, lo, an)); out.flush()
        print('%-22s depth=%d width=%d  low=%-7s any=%-7s' % (name, d, w, lo, an), flush=True)
