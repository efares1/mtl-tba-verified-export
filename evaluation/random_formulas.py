r"""Random MTL(0,inf) formulas for the differential test with CASAAL.

    python random_formulas.py [N] [seed] [path-to-casaal-folder]

Generates N formulas (default 100, seed 1) over the propositions p, q, r with
!, &, |, ->, [], <>, U, and the bounds <=k, <k, >=k, >k (k in 1..3) or none,
of depth at most 3, without hatted operators (CASAAL has none); writes
random_formulas.tsv (id, mtl2tba syntax, CASAAL syntax) and runs CASAAL on
every formula and on its negation, on the common domain (mutual exclusion of
the propositions), keeping the automata in casaal_out_rand/ (<id>.gv and
<id>_neg.gv).  The comparison is done by run_random_diff.sh (WSL).
"""
import os, random, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]
import run_casaal as rc   # reads sys.argv when imported
sys.argv = _argv

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = ['p', 'q', 'r']
BOUNDS = ['', '[<=1]', '[<=2]', '[<=3]', '[<2]', '[<3]', '[>=1]', '[>=2]', '[>1]', '[>2]']


def gen(rng, depth):
    if depth == 0 or rng.random() < 0.25:
        a = rng.choice(PROPS)
        return (a, a) if rng.random() < 0.8 else ('!' + a, '!' + a)
    k = rng.choice(['and', 'or', 'imp', 'box', 'dia', 'until', 'not'])
    if k in ('box', 'dia', 'not'):
        o, c = gen(rng, depth - 1)
        if k == 'not':
            return f'!({o})', f'!({c})'
        b = rng.choice(BOUNDS)
        op = '[]' if k == 'box' else '<>'
        return f'{op}{b} ({o})', f'{op}{b} ({c})'
    o1, c1 = gen(rng, depth - 1)
    o2, c2 = gen(rng, depth - 1)
    if k == 'and':
        return f'({o1}) & ({o2})', f'({c1}) /\\ ({c2})'
    if k == 'or':
        return f'({o1}) | ({o2})', f'({c1}) \\/ ({c2})'
    if k == 'imp':
        return f'({o1}) -> ({o2})', f'({c1}) -> ({c2})'
    b = rng.choice(BOUNDS)
    return f'({o1}) U{b} ({o2})', f'({c1}) U{b} ({c2})'


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    cdir = sys.argv[3] if len(sys.argv) > 3 else rc.CASAAL_DIR
    rng = random.Random(seed)
    forms, seen = [], set()
    while len(forms) < n:
        o, c = gen(rng, 3)
        if o in seen or not any(t in o for t in ('[]', '<>', 'U')):
            continue
        seen.add(o)
        forms.append((f'X{len(forms) + 1}', o, c))
    with open(os.path.join(HERE, 'random_formulas.tsv'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(f'# seed {seed}\n')
        for fid, o, c in forms:
            f.write(f'{fid}\t{o}\t{c}\n')
    work = tempfile.mkdtemp()
    for fn in os.listdir(cdir):
        if fn.endswith('.exe') or fn.endswith('.dll'):
            shutil.copy(os.path.join(cdir, fn), work)
    outdir = os.path.join(HERE, 'casaal_out_rand')
    os.makedirs(outdir, exist_ok=True)
    for fid, o, c in forms:
        for suffix, g in (('', c), ('_neg', '!(' + c + ')')):
            open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive(g) + '\n')
            dotf = os.path.join(work, 'dot_output.gv')
            if os.path.exists(dotf):
                os.remove(dotf)
            try:
                subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work,
                               capture_output=True, timeout=120)
                shutil.copy(dotf, os.path.join(outdir, fid + suffix + '.gv'))
            except Exception as e:
                print(fid + suffix, 'CASAAL failed:', type(e).__name__)
    print(len(forms), 'formulas')


if __name__ == '__main__':
    main()
