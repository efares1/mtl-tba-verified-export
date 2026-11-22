"""Floor probe: stored states of the system composed with a one-location automaton accepting every word (nothing to prune).
Any reduction of the requirement automaton by a zone-aware pass cannot go below this count."""
import os, sys, tempfile
sys.argv = ['x', '120']
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import run_tck as r, reqs
W = tempfile.mkdtemp()
for k in (2, 3, 4, 5):
    for sysname in ('ok', 'bad'):
        ours, cas, events = reqs.build('gateway', k, sysname)
        open(os.path.join(W, 'sys.xml'), 'w').write(reqs.system_xml('gateway', k, sysname))
        base = os.path.join(W, 'top')
        rc, out, err, sec, _ = r.run([r.EXE, '-nopdf', '-all-copy', '-o', base, 'true'], cwd=W, timeout=60)
        v = r.tck(','.join(events), W, [f'A:{base}.xml', 'SYS:' + os.path.join(W, 'sys.xml')])
        print(k, sysname, 'floor', v[0], v[1], v[2], flush=True)
