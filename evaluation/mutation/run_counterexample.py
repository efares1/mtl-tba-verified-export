"""Run a mutant (or the unmutated tool, id 'base') on a hand-built counterexample TBA and compare languages.
Run inside WSL:  python3 run_counterexample.py ID file.tba [nwords]"""
import os, sys, re, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mut_lib import *
mid, tba = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 200000
d = tempfile.mkdtemp()
res = {}
for pol, flags in POLICIES:
    base = os.path.join(d, pol)
    rc, out, err = sh([HOME + '/mut/exe/%s_tba_opt.exe' % mid, '-o', base, '-dump', base + '.opt.tba'] + flags + [tba])
    if rc != 0:
        res[pol] = 'crash'; continue
    a = os.path.join(d, 'in.can'); to_canon.from_tba(tba, a)
    for kind, f, typ in ([('opt', base + '.opt.tba', 'tba')] if pol == 'md' else []) + [(pol, base + '.xml', 'xml')]:
        b = os.path.join(d, kind + '.can')
        (to_canon.from_tba if typ == 'tba' else (lambda p, o: to_canon.from_xml(p, events_of(tba), o)))(f, b)
        rc, out, err = sh([LC, a, b, str(n), '5'])
        m = re.search(r'mismatch=(\d+) first=(-?\d+) accA=(\d+) accB=(\d+)|mismatch=(\d+) first=(-?\d+) accA=(\d+)', out)
        res[kind] = re.sub(r'words=\d+ pairs=\d+ ', '', out.strip())
print(mid, os.path.basename(tba), res)
