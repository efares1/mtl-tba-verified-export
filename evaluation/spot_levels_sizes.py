"""Sizes and generation time of the negated automata for several Spot post-processing levels.
Usage (WSL): python3 spot_levels_sizes.py [LIMIT_SECONDS]
Writes spot_levels_sizes_any.tsv: id, level, exp_locs, exp_trans, exp_clocks, seconds (or timeout)."""
import os, subprocess, sys, tempfile, shutil, time

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 120
LEVELS = ['low', 'any']
hdr = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\t')

def run(formula, level, W):
    t0 = time.time()
    try:
        r = subprocess.run([EXE, '-nopdf', '-stats', '-spot-level', level, '-o', 'x', formula],
                           cwd=W, capture_output=True, text=True, timeout=LIMIT)
    except subprocess.TimeoutExpired:
        return ['timeout', '', '', '', '%.1f' % LIMIT]
    dt = time.time() - t0
    if r.returncode != 0:
        return ['fail', '', '', '', '%.1f' % dt]
    d = dict(zip(hdr, r.stdout.strip().split('\n')[-1].split('\t')))
    return ['ok', d['exp_locs'], d['exp_trans'], d['exp_clocks'], '%.2f' % dt]

with open(os.path.join(HERE, 'spot_levels_sizes_any.tsv'), 'w') as o:
    o.write('id\tlevel\tstatus\tlocs\ttrans\tclocks\tseconds\n')
    for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
        rec = l.rstrip('\n').split('\t')
        if len(rec) < 4 or l.startswith('#'):
            continue
        i, ours = rec[0], rec[2]
        W = tempfile.mkdtemp()
        try:
            for lv in LEVELS:
                row = [i, lv] + run('!(%s)' % ours, lv, W)
                o.write('\t'.join(row) + '\n'); o.flush(); print('\t'.join(row), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
