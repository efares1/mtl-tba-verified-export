"""Does the checker catch bad clock allocations?  (testing of alloc_ok; the pass itself is proved)

For each formula the negated automaton is exported with a RANDOM allocation (mtl2tba -alloc -alloc-fuzz SEED).  The
checker decides; with -alloc-unchecked the allocation is applied anyway, and the resulting automaton is compared with the
independent MTL judge (evaluation/differential) on random lasso words.  Expected: no accepted allocation changes the
language; some rejected allocations do, which is why the check is needed.
Usage (WSL): python3 alloc_fuzz.py OUT.tsv WORDS SEEDS [MAXFORMULAS]"""
import os, re, random, subprocess, sys, tempfile, shutil, threading
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'differential'))
from dlib import OursAut, parse_mtl, judge, mtl_props
from run_diff_words import constants, random_word
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OUT, NWORDS, NSEEDS = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
MAXF = int(sys.argv[4]) if len(sys.argv) > 4 else 10 ** 9


def gen(form, seed, unchecked, W, name):
    cmd = [EXE, '-nopdf', '-v', '-alloc', '-alloc-fuzz', str(seed)] + (['-alloc-unchecked'] if unchecked else []) + ['-o', os.path.join(W, name), form]
    r = subprocess.run(cmd, cwd=W, capture_output=True, text=True, timeout=120)
    acc = re.search(r'certificate accepted by the checker: (\w+)', r.stderr + r.stdout)
    return (os.path.join(W, name + '.xml') if r.returncode == 0 else None), (acc.group(1) if acc else 'NA')


def main():
    rng = random.Random(7)
    items = []
    for fn, st in (('formulas.tsv', 'benchmark'), ('random_formulas_4col.tsv', 'random')):
        for l in open(os.path.join(HERE, fn), encoding='utf8'):
            if l.strip() and not l.startswith('#'):
                p = l.rstrip('\n').split('\t')
                if st == 'benchmark' and (re.match(r'N[5-9]|R[4-9]', p[0]) or '^' in p[2]):
                    continue
                if len(re.findall(r'[\[(][<>]=?\d+[\])]|U\[[<>]=?\d+\]|\[[<>]=?\d+\]', p[2])) < 2:
                    continue          # fewer than two timed operators: at most one clock
                items.append((p[0], st, p[2]))
    items = items[:MAXF]
    W = tempfile.mkdtemp()
    try:
        with open(OUT, 'w', encoding='utf8') as o:
            o.write('id\tset\tseed\taccepted\tclocks_before\tclocks_after\tchanged_language_checked\tchanged_language_unchecked\n')
            for fid, st, formula in items:
                try:
                    f = parse_mtl(formula)
                except Exception:
                    continue
                props = sorted(mtl_props(f))
                consts = constants(f)
                words = [random_word(rng, props, consts) for _ in range(NWORDS)]
                truth = [(not judge(f, w)) for w in words]    # negated automaton accepts the words the formula rejects
                base, _ = gen('!(%s)' % formula, 0, False, W, 'base') if False else (None, None)
                for seed in range(1, NSEEDS + 1):
                    try:
                        pc, acc = gen('!(%s)' % formula, seed, False, W, 'chk')
                        pu, _ = gen('!(%s)' % formula, seed, True, W, 'unc')
                        if not pc or not pu:
                            continue
                        ac, au = OursAut(pc), OursAut(pu)
                        dc = any(ac.accepts(w) != t for w, t in zip(words, truth))
                        du = any(au.accepts(w) != t for w, t in zip(words, truth))
                        row = [fid, st, seed, acc, len(ac.clocks), len(au.clocks), int(dc), int(du)]
                        o.write('\t'.join(map(str, row)) + '\n')
                        o.flush()
                    except Exception as e:
                        print(fid, seed, 'error', e, flush=True)
                print(fid, 'done', flush=True)
    finally:
        shutil.rmtree(W, ignore_errors=True)


threading.stack_size(512 * 1024 * 1024)
sys.setrecursionlimit(1000000)
th = threading.Thread(target=main)
th.start(); th.join()
