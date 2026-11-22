"""Gateway k=4, correct system: generation with no optimization (-n 0 -all-copy), limit 300 s.  Usage (WSL): python3 ag_none_k4.py"""
import os, sys, time, tempfile, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.argv = ['x', '120']
import run_tck as r, reqs

W = tempfile.mkdtemp()
ours, cas, events = reqs.build('gateway', 4, 'ok')
t0 = time.time()
try:
    p = subprocess.run([r.EXE, '-nopdf', '-stats', '-n', '0', '-all-copy', '-o', os.path.join(W, 'none'), ours],
                       cwd=W, capture_output=True, text=True, timeout=300)
    res = 'finished rc=%d in %.1f s' % (p.returncode, time.time() - t0)
except subprocess.TimeoutExpired:
    res = 'timeout after 300 s'
print(res)
open(os.path.join(HERE, 'ag_none_k4.txt'), 'w').write(res + '\n')
