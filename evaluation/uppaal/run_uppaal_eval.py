"""Run verifyta (UPPAAL 5.0.0) on the models of gen_models.py and write results.tsv.

    python run_uppaal_eval.py [LIMIT_SECONDS] [name-substring ...]

verifyta options: -u (summary: states stored/explored, memory), -s, -q, -t0 (some trace),
-o 0 (breadth-first, deterministic).  Wall time is measured by this script (median of 3
runs, including model parsing and process start); memory is verifyta's own
'Resident memory used' / 'Virtual memory used' line.  One verifyta process at a time.
A satisfied E<> query stops at the first hit, so its state counts are partial.
"""
import json, os, re, statistics, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
V = os.environ.get('VERIFYTA', r'C:\Program Files (x86)\UPPAAL-5.0.0\bin\verifyta.exe')
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 120
ONLY = [a for a in sys.argv[1:] if not a.isdigit()]
REPS = int(os.environ.get('REPS', '3'))
man = json.load(open(os.path.join(HERE, 'manifest.json')))
cols = ['name', 'block', 'case', 'system', 'variant', 'expected', 'verdict', 'agree', 'stored', 'explored',
        'wall_s', 'cpu_ms', 'resident_kib', 'virtual_kib', 'diag_atoms']
rows = []

def once(name):
    t = time.perf_counter()
    try:
        r = subprocess.run([V, '-u', '-s', '-q', '-t0', '-o', '0', name + '.xml', name + '.q'],
                           cwd=os.path.join(HERE, 'models'), capture_output=True, text=True, timeout=LIMIT)
        out = r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return time.perf_counter() - t, 'timeout'
    return time.perf_counter() - t, out

with open(os.path.join(HERE, 'results.tsv'), 'w', encoding='utf8') as o:
    o.write('\t'.join(cols) + '\n')
    for m in man:
        if ONLY and not any(s in m['name'] for s in ONLY):
            continue
        walls, out = [], ''
        for _ in range(REPS):
            w, out = once(m['name'])
            walls.append(w)
            if out == 'timeout':
                break
        if out == 'timeout':
            row = [m['name'], m['block'], m['case'], m['system'], m['variant'], m['expected'], 'timeout', 'NA',
                   'NA', 'NA', '>%d' % LIMIT, 'NA', 'NA', 'NA', m['diag']]
        else:
            verdict = ('NOT satisfied' if 'NOT satisfied' in out else 'satisfied' if 'is satisfied' in out
                       else 'error: ' + re.sub(r'\s+', ' ', out.strip())[-80:])
            g = lambda k: (re.search(k + r'\s*:\s*(\d+)', out) or [None, 'NA'])[1]
            agree = ('yes' if verdict.replace('NOT satisfied', 'not satisfied') == m['expected'] else
                     'n/a' if m['block'] == 'pos' else 'NO')
            row = [m['name'], m['block'], m['case'], m['system'], m['variant'], m['expected'], verdict, agree,
                   g('States stored'), g('States explored'), '%.3f' % statistics.median(walls),
                   g('CPU user time used'), g('Resident memory used'), g('Virtual memory used'), m['diag']]
        o.write('\t'.join(map(str, row)) + '\n'); o.flush()
        print('\t'.join(map(str, row)), flush=True)
