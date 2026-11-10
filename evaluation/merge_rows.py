"""Merge the rows of <file>.only (written with ONLY=...) into <file>:
    python3 merge_rows.py spot_validation.tsv [ours_runs.tsv ...]
For ours_runs.only.tsv and spot_det.only.tsv, pass ours_runs.tsv and
spot_det.tsv.  Rows are keyed by their first column (all rows of an id are
replaced)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
for fn in sys.argv[1:]:
    base = os.path.join(HERE, fn)
    only = base + '.only'
    if not os.path.exists(only):
        root, ext = os.path.splitext(base)
        only = root + '.only' + ext
    old = open(base, encoding='utf-8').read().rstrip('\n').split('\n')
    new = open(only, encoding='utf-8').read().rstrip('\n').split('\n')[1:]
    ids = {l.split('\t')[0] for l in new}
    out, done = [old[0]], set()
    for l in old[1:]:
        i = l.split('\t')[0]
        if i in ids:
            if i not in done:
                out += [n for n in new if n.split('\t')[0] == i]
                done.add(i)
        else:
            out.append(l)
    out += [n for n in new if n.split('\t')[0] not in done and n.split('\t')[0] not in {l.split('\t')[0] for l in old}]
    open(base, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
    os.remove(only)
    print(fn, 'merged', sorted(ids))
