"""Greedy reduction of a TBA on which the exported UPPAAL XML and the input differ under lang_cmp.
usage (WSL): python3 reduce.py in.tba [policy: md|ac] [WORDS]
Removes transitions one at a time while the mismatch persists; writes <in>.min.tba and prints it."""
import os, sys, subprocess, re, shutil, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'mutation'))
import to_canon
from mut_lib import sh, events_of, LC, HOME

EXE = HOME + '/mut/exe/base_tba_opt.exe'
src = sys.argv[1]
pol = sys.argv[2] if len(sys.argv) > 2 else 'md'
WORDS = sys.argv[3] if len(sys.argv) > 3 else '20000'
flags = ['-all-copy'] if pol == 'ac' else []
W = tempfile.mkdtemp()


def mism(lines):
    p = W + '/x.tba'
    open(p, 'w').write('\n'.join(lines) + '\n')
    base = W + '/x'
    rc, o, e = sh([EXE, '-o', base] + flags + [p], timeout=60)
    if rc != 0 or not os.path.exists(base + '.xml'):
        return False
    try:
        to_canon.from_tba(p, W + '/a.can'); to_canon.from_xml(base + '.xml', events_of(p), W + '/b.can')
    except Exception:
        return False
    rc, o, e = sh([LC, W + '/a.can', W + '/b.can', WORDS, '31'], timeout=300)
    m = re.search(r'mismatch=(\d+)', o)
    return bool(m) and int(m.group(1)) > 0


lines = [l.rstrip('\n') for l in open(src) if l.strip() and not l.startswith('#')]
assert mism(lines), 'no mismatch to reduce'
head = [l for l in lines if not l.startswith('t ')]
tr = [l for l in lines if l.startswith('t ')]
changed = True
while changed:
    changed = False
    for i in range(len(tr)):
        cand = tr[:i] + tr[i + 1:]
        if mism(head + cand):
            tr = cand; changed = True; break
# drop guard atoms and reset entries one at a time
def fields(l):
    h, lab, g, r = l.split('|')
    return h, lab, g.split(), r.split()
changed = True
while changed:
    changed = False
    for i in range(len(tr)):
        h, lab, g, r = fields(tr[i])
        for kind in ('g', 'r', 'l'):
            items = {'g': g, 'r': r, 'l': lab.split()}[kind]
            for k in range(len(items)):
                it = items[:k] + items[k + 1:]
                gg, rr, ll = (it, r, lab.split()) if kind == 'g' else ((g, it, lab.split()) if kind == 'r' else (g, r, it))
                nl = '%s| %s | %s | %s' % (h, ' '.join(ll), ' '.join(gg), ' '.join(rr))
                if mism(head + tr[:i] + [nl] + tr[i + 1:]):
                    tr[i] = nl; changed = True; break
            if changed: break
        if changed: break
out = head + tr
open(src[:-4] + '.min.tba', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
shutil.rmtree(W, ignore_errors=True)
