"""Validate the testing oracle on the UNMUTATED tool, and on deliberately wrong automata.
Run inside WSL: python3 validate_oracle.py"""
import os, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mut_lib import *

exe = HOME + '/mut/exe/base_tba_opt.exe'
gold = HOME + '/mut/out/base'
shutil.rmtree(gold, ignore_errors=True)
st = run_corpus(exe, gold)
bad = [k for k, v in st.items() if v != 0]
print('tba_opt failures on the unmutated tool:', bad)
work = HOME + '/mut/work_can'
shutil.rmtree(work, ignore_errors=True)
for n in [int(a) for a in sys.argv[1:]] or [1000, 20000]:
    res = lang_check(gold, n, 1, work)
    mism = {k: v for k, v in res.items() if v[0] != 0}
    nacc = sum(1 for k, v in res.items() if v[2] > 0)
    print('words per input %d: %d comparisons, %d with accepted words, mismatches: %s' % (n, len(res), nacc, mism))
# deliberately wrong automata: take each optimized TBA and flip an accepting set / drop a transition; the oracle must notice some
import random, to_canon
rng = random.Random(5)
caught = tried = 0
for p in CORPUS:
    name = os.path.basename(p)[:-4]
    a = canon_input(p, work)
    lines = open(a).read().split('\n')
    trs = [i for i, l in enumerate(lines) if l.startswith('T ')]
    if len(trs) < 2: continue
    # wrong automaton: drop one transition
    for drop in trs[:4]:
        b = os.path.join(work, 'wrong.can')
        open(b, 'w').write('\n'.join(l for i, l in enumerate(lines) if i != drop))
        rc, out, err = sh([LC, a, b, '5000', '3'])
        m = re.search(r'mismatch=(\d+)', out)
        tried += 1
        caught += int(m.group(1)) > 0
print('deliberately wrong automata (one transition dropped): detected %d of %d' % (caught, tried))
