"""Stronger baseline T3 for the mutation study: for each mutant, take every input of the 3,000-automaton fuzz corpus on which
the mutant's output differs from the unmutated tool's, and compare the output with the input on EVERY lasso word
(prefix 0..3, loop 1..3, at most 4 positions, all events, delays in DELAYS half-units, all-zero initial valuation).
The check is exact on this finite word set (not on the whole language).
Run inside WSL after fuzz_large.py (it reuses ~/mut/out_large):  python3 exh_check.py ID [ID ...]
Writes results/exh_<ID>.tsv: input, policy, kind, words, mismatches"""
import os, sys, glob, re, shutil
from multiprocessing import Pool
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mut_lib, to_canon
from mut_lib import sh, events_of, file_bytes, HOME

CORP = HOME + '/mut/corpus_large'
OUT = HOME + '/mut/out_large'
EXH = HOME + '/mut/exe/lang_cmp_exh'
DELAYS = os.environ.get('DELAYS', '0,1,2,4,10')
VALS = os.environ.get('VALS', '0,2,4,6,10')
MAXPOS = os.environ.get('MAXPOS', '3')


def check(args):
    mid, name = args
    p = CORP + '/%s.tba' % name
    evs = events_of(p)
    work = OUT + '/xwork_%s_%s' % (mid, name)
    os.makedirs(work, exist_ok=True)
    a = work + '/in.can'
    to_canon.from_tba(p, a)
    res = []
    for pol, _ in mut_lib.POLICIES:
        base = '%s/%s/%s.%s' % (OUT, mid, name, pol)
        gbase = '%s/base/%s.%s' % (OUT, name, pol)
        if all(file_bytes(base + s) == file_bytes(gbase + s) for s in ('.xml', '.opt.tba')):
            continue
        kinds = [('xml', base + '.xml')] + ([('tba', base + '.opt.tba')] if pol == 'md' else [])
        for typ, f in kinds:
            if not os.path.exists(f):
                res.append((name, pol, typ, -1, -1)); continue
            b = work + '/%s.%s.can' % (pol, typ)
            try:
                (to_canon.from_xml(f, evs, b) if typ == 'xml' else to_canon.from_tba(f, b))
            except Exception:
                res.append((name, pol, typ, -1, -1)); continue
            rc, out, err = sh([EXH, a, b, 'exh', DELAYS, VALS, MAXPOS], timeout=120)
            m = re.search(r'words=(\d+) pairs=\d+ mismatch=(\d+)', out)
            res.append((name, pol, typ, int(m.group(1)), int(m.group(2))) if m else (name, pol, typ, -1, -1))
    shutil.rmtree(work, ignore_errors=True)
    return res


if __name__ == '__main__':
    ids = sys.argv[1:]
    os.makedirs(os.path.join(HERE, 'results'), exist_ok=True)
    for mid in ids:
        names = []
        for p in sorted(glob.glob(CORP + '/*.tba')):
            name = os.path.basename(p)[:-4]
            for pol, _ in mut_lib.POLICIES:
                base = '%s/%s/%s.%s' % (OUT, mid, name, pol)
                gbase = '%s/base/%s.%s' % (OUT, name, pol)
                if not all(file_bytes(base + s) == file_bytes(gbase + s) for s in ('.xml', '.opt.tba')):
                    names.append(name); break
        with Pool(8) as pool:
            allres = pool.map(check, [(mid, n) for n in names], chunksize=1)
        rows = [r for rs in allres for r in rs]
        with open(os.path.join(HERE, 'results', 'exh_%s.tsv' % mid), 'w') as f:
            f.write('input\tpolicy\tkind\twords\tmismatches\n')
            for r in rows:
                f.write('%s\t%s\t%s\t%d\t%d\n' % r)
        bad = sorted({r[0] for r in rows if r[4] > 0})
        print('%s\tchanged_inputs=%d\tinputs_with_mismatch=%d\tfirst=%s' % (mid, len(names), len(bad), bad[0] if bad else ''), flush=True)
