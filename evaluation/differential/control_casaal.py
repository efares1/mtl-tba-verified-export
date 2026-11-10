"""Negative control for the CASAAL evaluator: run casaal.exe on the negation of a MUTATED formula g
and compare its automaton with the judge on the original formula f.  Usage (WSL): python3 control_casaal.py N SEED"""
import itertools, os, random, re, shutil, subprocess, sys, tempfile, threading
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from dlib import *
import run_diff_words as rw
N, SEED = int(sys.argv[1]), int(sys.argv[2])
CAS = '/mnt/c/Users/user/Desktop/casaal/casaal'
SCRATCH = '/mnt/c/Users/user/.claude/jobs/d3cb801e/tmp'

# (mtl2tba syntax of f, CASAAL syntax of the mutated g, mtl2tba syntax of g for the property set)
PAIRS = [
    ('[](p -> <>[<=5] q)', '[](p -> <>[<5] q)'),
    ('[](p -> <>[<=5] q)', '[](p -> <>[<=4] q)'),
    ('[](p -> (p U[<=4] q))', '[](p -> (p U[<4] q))'),
    ('[]<>[<=5] p', '[]<>[<5] p'),
    ('(<>[<=5] p) & ([][<2] !p)', '(<>[<=5] p) /\\ ([][<=2] !p)'),
    ('[](p -> (<>[<=5] q & [][<2] !q))', '[](p -> ((<>[<=5] q) /\\ ([][<=2] !q)))'),
    ('[](p -> <>[>=2] q)', '[](p -> <>[>2] q)'),
]


def exclusive(f):
    props = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)))
    pairs = ['([](!(%s /\\ %s)))' % (a, b) for a, b in itertools.combinations(props, 2)]
    return ' /\\ '.join(['(%s)' % f] + pairs) if pairs else f


def main():
    rng = random.Random(SEED)
    work = tempfile.mkdtemp(dir=SCRATCH)
    for fn in os.listdir(CAS):
        if fn.lower().endswith(('.exe', '.dll')):
            shutil.copy(os.path.join(CAS, fn), work)
    print('formula_judged\tcasaal_mutated\twords\tdiffering_words')
    for f, g in PAIRS:
        open(os.path.join(work, 'f.txt'), 'w').write(exclusive('!(' + g + ')') + '\n')
        dot = os.path.join(work, 'dot_output.gv')
        if os.path.exists(dot):
            os.remove(dot)
        subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work, capture_output=True, timeout=120)
        pf = parse_mtl(f)
        props = sorted(mtl_props(pf))
        aut = GvAut(dot, props)
        consts = rw.constants(pf)
        diff = 0
        for _ in range(N):
            w = rw.random_word(rng, props, consts)
            if aut.accepts(w) != (not judge(pf, w)):
                diff += 1
        print('%s\t%s\t%d\t%d' % (f, g, N, diff), flush=True)
    shutil.rmtree(work, ignore_errors=True)


threading.stack_size(256 * 1024 * 1024)
sys.setrecursionlimit(1000000)
t = threading.Thread(target=main); t.start(); t.join()
