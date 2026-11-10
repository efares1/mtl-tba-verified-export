"""Differential test: mtl2tba (default and -all-copy export) and CASAAL against a ground-truth
MTL evaluator on random ultimately periodic timed words.

    python3 run_diff.py SET WORDS SEED [ID ...]       (WSL; SET = bench | random)

For every formula f and polarity (f, !f) and every random lasso word w:
    expected = judge(f, w)  (or its negation)
    ours_def, ours_ac, casaal = acceptance of the automata generated for that polarity.
Any automaton whose verdict differs from `expected` is a disagreement; it is minimized and logged.
Writes diff_<SET>.tsv (one row per formula/polarity/tool) and disagreements_<SET>.txt."""
import os, random, subprocess, sys, threading, time, json
HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
from dlib import *   # noqa

EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
AUTO = os.path.join(HERE, 'automata')
os.makedirs(AUTO, exist_ok=True)
SET, NWORDS, SEED = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
ONLY = set(sys.argv[4:])
BENCH = ['F1', 'F2', 'F3', 'F3b', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12', 'F13', 'F14',
         'R1', 'R2', 'R3', 'N1', 'N2', 'N3', 'N4']


def load_formulas():
    out = []
    if SET == 'bench':
        for l in open(os.path.join(EV, 'formulas.tsv'), encoding='utf8'):
            if l.startswith('#') or not l.strip():
                continue
            p = l.rstrip('\n').split('\t')
            if p[0] not in BENCH or (ONLY and p[0] not in ONLY):
                continue
            cas = p[3]
            usable = not (cas == '-' or cas.startswith('~'))
            gvn = os.path.join(EV, 'casaal_out_neg', p[0] + '.gv')
            gvp = os.path.join(EV, 'casaal_out', p[0] + '.gv')
            out.append((p[0], p[2], gvn if usable and os.path.exists(gvn) else None,
                        gvp if usable and os.path.exists(gvp) else None))
    else:
        for l in open(os.path.join(EV, 'random_formulas.tsv'), encoding='utf8'):
            if l.startswith('#') or not l.strip():
                continue
            p = l.rstrip('\n').split('\t')
            if ONLY and p[0] not in ONLY:
                continue
            out.append((p[0], p[1], os.path.join(EV, 'casaal_out_rand', p[0] + '_neg.gv'),
                        os.path.join(EV, 'casaal_out_rand', p[0] + '.gv')))
    return out


def gen_ours(fid, formula, pol, variant):
    """returns the XML path or None"""
    path = os.path.join(AUTO, '%s_%s_%s.xml' % (fid, pol, variant))
    if os.path.exists(path):
        return path
    import tempfile, shutil
    w = tempfile.mkdtemp()
    arg = formula if pol == 'pos' else '!(%s)' % formula
    cmd = [EXE, '-nopdf', '-o', os.path.join(w, 'o')] + (['-all-copy'] if variant == 'ac' else []) + [arg]
    try:
        r = subprocess.run(cmd, cwd=w, capture_output=True, text=True, timeout=120)
        if r.returncode != 0 or not os.path.exists(os.path.join(w, 'o.xml')):
            return None
        shutil.copy(os.path.join(w, 'o.xml'), path)
        return path
    except subprocess.TimeoutExpired:
        return None
    finally:
        shutil.rmtree(w, ignore_errors=True)


from run_diff_words import constants, random_word  # noqa


def minimize(bad, w):
    """greedy shrinking of a word while bad(w) stays true"""
    changed = True
    while changed:
        changed = False
        # drop a position (keep the loop non-empty)
        for i in range(w.n):
            if w.n == 1:
                break
            if i < w.s:
                s2 = w.s - 1
            elif w.q == 1:
                continue
            else:
                s2 = w.s
            L = w.L[:i] + w.L[i + 1:]
            D = w.D[:i] + w.D[i + 1:]
            t0 = w.t0
            if i == 0:
                t0 = w.t0 + w.D[0]
            try:
                w2 = Word(L, s2, D, t0)
            except AssertionError:
                continue
            if bad(w2):
                w, changed = w2, True
                break
        if changed:
            continue
        # shrink a delay
        for i in range(w.n):
            for new in (1, w.D[i] - 1, w.D[i] // 2):
                if 1 <= new < w.D[i]:
                    D = list(w.D); D[i] = new
                    w2 = Word(w.L, w.s, D, w.t0)
                    if bad(w2):
                        w, changed = w2, True
                        break
            if changed:
                break
        if changed:
            continue
        for new in (1, w.t0 - 1, w.t0 // 2):
            if 1 <= new < w.t0:
                w2 = Word(w.L, w.s, w.D, new)
                if bad(w2):
                    w, changed = w2, True
                    break
    return w


def main():
    rng = random.Random(SEED)
    rows = []
    dis_out = open(os.path.join(HERE, 'disagreements_%s.txt' % SET), 'a')
    tsv = open(os.path.join(HERE, 'diff_%s.tsv' % SET), 'a')
    if os.path.getsize(os.path.join(HERE, 'diff_%s.tsv' % SET)) == 0:
        tsv.write('id\tformula\tpolarity\ttool\twords\taccepting\tdisagreements\tstatus\n')
    for fid, formula, gvn, gvp in load_formulas():
        t_start = time.time()
        f = parse_mtl(formula)
        props = sorted(mtl_props(f))
        consts = constants(f)
        words = [random_word(rng, props, consts) for _ in range(NWORDS)]
        truth = [judge(f, w) for w in words]
        for pol, gv in (('neg', gvn), ('pos', gvp)):
            tools = {}
            for variant in ('def', 'ac'):
                p = gen_ours(fid, formula, pol, variant)
                if p:
                    tools['ours_' + variant] = OursAut(p)
            if gv and os.path.exists(gv):
                try:
                    tools['casaal'] = GvAut(gv, props)
                except Exception as e:
                    print(fid, pol, 'casaal parse error', e, flush=True)
            for name, aut in tools.items():
                acc = bad = 0
                firstbad = None
                for w, tv in zip(words, truth):
                    exp = (not tv) if pol == 'neg' else tv
                    got = aut.accepts(w)
                    acc += got
                    if got != exp:
                        bad += 1
                        if firstbad is None:
                            firstbad = (w, exp, got)
                if firstbad:
                    w0, exp, got = firstbad
                    wm = minimize(lambda ww, aut=aut, pol=pol: aut.accepts(ww) != ((not judge(f, ww)) if pol == 'neg' else judge(f, ww)), w0)
                    dis_out.write('%s\t%s\t%s\tformula=%s\texpected(judge)=%s got=%s\nword=%r\nminimized=%r\nletters=%s s=%d delays(half-units)=%s t0=%d\n\n'
                                  % (fid, pol, name, formula, exp, got, w0, wm, wm.L, wm.s, wm.D, wm.t0))
                    dis_out.flush()
                row = [fid, formula, pol, name, len(words), acc, bad, 'ok' if not bad else 'DISAGREE']
                tsv.write('\t'.join(map(str, row)) + '\n'); tsv.flush()
                print('\t'.join(map(str, row)), flush=True)
            if not tools:
                print(fid, pol, 'no automata', flush=True)
        print(fid, 'done in %.1fs; judge-true fraction %.2f' % (time.time() - t_start, sum(truth) / len(truth)), flush=True)


threading.stack_size(512 * 1024 * 1024)
sys.setrecursionlimit(1000000)
th = threading.Thread(target=main)
th.start(); th.join()
