"""Sizes and generation time of the negated automata for the large patterns: ours (default
options of the current tool, with optimization and with -n 0) against CASAAL's automaton of the
negation (casaal_out_neg/<id>.gv, symbolic edges after removing the dummy initial edge).
Usage (WSL): python3 neg_sizes_vs_casaal.py LIMIT_SECONDS ID [ID ...]
Writes neg_sizes_vs_casaal.tsv: id, tool, locs, trans, clocks, status, seconds."""
import os, re, subprocess, sys, tempfile, shutil, time

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
LIMIT = int(sys.argv[1])
IDS = sys.argv[2:]
hdr = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\t')

def casaal_size(path):
    txt = open(path, encoding='utf8').read()
    states, edges = set(), 0
    for m in re.finditer(r'^\s*(\w+)\s*->\s*(\w+)\s*(?:\[label="(.*?)"\])?\s*$', txt, re.M | re.S):
        a, b = m.group(1), m.group(2)
        if a == '0':
            continue
        states |= {a, b}; edges += 1
    return len(states), edges

def ours(formula, extra, W):
    t0 = time.time()
    try:
        r = subprocess.run([EXE, '-nopdf', '-stats'] + extra + ['-o', 'x', formula],
                           cwd=W, capture_output=True, text=True, timeout=LIMIT)
    except subprocess.TimeoutExpired:
        return ['', '', '', 'timeout', '%.1f' % LIMIT]
    dt = time.time() - t0
    if r.returncode != 0:
        return ['', '', '', 'fail', '%.1f' % dt]
    d = dict(zip(hdr, r.stdout.strip().split('\n')[-1].split('\t')))
    return [d['exp_locs'], d['exp_trans'], d['exp_clocks'], 'ok', '%.2f' % dt]

forms = {}
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    rec = l.rstrip('\n').split('\t')
    if len(rec) >= 4 and not l.startswith('#'):
        forms[rec[0]] = rec[2]

with open(os.path.join(HERE, 'neg_sizes_vs_casaal.tsv'), 'w') as o:
    o.write('id\ttool\tlocs\ttrans\tclocks\tstatus\tseconds\n')
    for i in IDS:
        W = tempfile.mkdtemp()
        try:
            rows = [[i, 'ours'] + ours('!(%s)' % forms[i], [], W),
                    [i, 'ours_n0'] + ours('!(%s)' % forms[i], ['-n', '0'], W)]
            gv = os.path.join(HERE, 'casaal_out_neg', i + '.gv')
            if os.path.exists(gv):
                s = casaal_size(gv)
                rows.append([i, 'casaal', str(s[0]), str(s[1]), '', 'ok', ''])
            for row in rows:
                o.write('\t'.join(row) + '\n'); o.flush(); print('\t'.join(row), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
