"""Benchmark half of the mutation study: the MTL patterns F1-F14, F3b, R1-R3, N1-N3 (positive and
negated), run through mtl2tba.  Run inside WSL.
Golden reference (language): unmutated mtl2tba with -n 0 (export only, so the optimizer is bypassed).
Regression reference (bytes): unmutated mtl2tba with the same options as the mutant."""
import os, re, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mut_lib import *

EVAL = os.path.join(HERE, '..')
IDS = ['F%d' % i for i in range(1, 15)] + ['F3b', 'R1', 'R2', 'R3', 'N1', 'N2', 'N3']


def patterns():
    out = []
    for l in open(os.path.join(EVAL, 'formulas.tsv'), encoding='utf8'):
        if l.startswith('#') or not l.strip():
            continue
        w = l.rstrip('\n').split('\t')
        if w[0] in IDS:
            out.append((w[0], w[2]))
    return out


def run_bench(exe, outdir, extra=(), tag='d'):
    os.makedirs(outdir, exist_ok=True)
    st = {}
    for (i, f) in patterns():
        for pol, formula in (('pos', f), ('neg', '!(%s)' % f)):
            base = os.path.join(outdir, '%s.%s.%s' % (i, pol, tag))
            rc, out, err = sh([exe, '-nopdf', '-o', base] + list(extra) + [formula], timeout=120)
            st[(i, pol, tag)] = rc
    return st


def chans(xml):
    m = re.search(r'<declaration>chan ([^;]*);', open(xml).read())
    return [c.strip() for c in m.group(1).split(',') if c.strip() != 'other']


def compare_bench(gold_dir, mut_dir, nwords, seed, work):
    """returns (bytes_diff, lang_mismatch): sets of (id,pol,tag) where the output bytes differ from the
    unmutated tool with the same options / where the language (vs unmutated -n 0) differs."""
    os.makedirs(work, exist_ok=True)
    bdiff = set(); ldiff = {}
    for (i, f) in patterns():
        for pol in ('pos', 'neg'):
            g0 = os.path.join(gold_dir, '%s.%s.n0.xml' % (i, pol))
            if not os.path.exists(g0):
                continue
            evs = chans(g0)
            a = os.path.join(work, '%s.%s.gold.can' % (i, pol))
            to_canon.from_xml(g0, evs, a)
            for tag in ('d', 'ac'):
                mx = os.path.join(mut_dir, '%s.%s.%s.xml' % (i, pol, tag))
                gx = os.path.join(gold_dir, '%s.%s.%s.xml' % (i, pol, tag))
                if file_bytes(mx) != file_bytes(gx):
                    bdiff.add((i, pol, tag))
                if not os.path.exists(mx):
                    ldiff[(i, pol, tag)] = (-1, -1, 0); continue
                b = os.path.join(work, '%s.%s.%s.can' % (i, pol, tag))
                try:
                    to_canon.from_xml(mx, evs, b)
                except Exception:
                    ldiff[(i, pol, tag)] = (-2, -1, 0); continue
                rc, out, err = sh([LC, a, b, str(nwords), str(seed)], timeout=600)
                m = re.search(r'mismatch=(\d+) first=(-?\d+) accA=(\d+)', out)
                ldiff[(i, pol, tag)] = (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else (-3, -1, 0)
    return bdiff, ldiff


def run_all(exe, outdir):
    st = {}
    st.update(run_bench(exe, outdir, [], 'd'))
    st.update(run_bench(exe, outdir, ['-all-copy'], 'ac'))
    return st


if __name__ == '__main__':
    gold = HOME + '/mut/out/bench_base'
    shutil.rmtree(gold, ignore_errors=True)
    exe = HOME + '/mut/exe/base_mtl2tba.exe'
    st = run_bench(exe, gold, ['-n', '0'], 'n0')
    st.update(run_all(exe, gold))
    print('failures', [k for k, v in st.items() if v != 0])
    work = HOME + '/mut/work_bench'
    shutil.rmtree(work, ignore_errors=True)
    for n in (1000, 20000):
        b, l = compare_bench(gold, gold, n, 1, work)
        print(n, 'byte diffs', len(b), 'lang mismatches', {k: v for k, v in l.items() if v[0] != 0},
              'comparisons with accepted words', sum(1 for v in l.values() if v[2] > 0), 'of', len(l))
