"""Stronger testing baseline for the mutation study: random-automaton fuzzing with a corpus about 25 times
larger than the one used for T1/T2 (3,000 random TBAs instead of 120, same generator, other seed).
For each mutant and each input we run the mutant's tba_opt (both export policies) and compare its output
bytes with the unmutated tool's; only inputs whose output differs are then tested for language equality
against the input with the bounded language test (lang_cmp, WORDS words per input), because an output that is
byte-identical to the unmutated tool's has the language of the unmutated tool, which the proofs equate with the input's.
Run inside WSL:  python3 fuzz_large.py [N] [WORDS] [ID ...]
Writes results/fuzz_large.tsv:  id, inputs_with_changed_output, inputs_with_language_mismatch, first_input"""
import os, sys, random, subprocess, shutil, glob, re
from multiprocessing import Pool
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mut_lib, to_canon
from mut_lib import sh, events_of, file_bytes, LC, HOME

N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
WORDS = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
IDS = sys.argv[3:] or ['M%02d' % i for i in range(1, 23)]
MODE = os.environ.get('DIRECTED', '0')
DIRECTED = MODE in ('1', '2')
SUF = {'1': '_directed', '2': '_boundary'}.get(MODE, '_large')
CORP = HOME + '/mut/corpus' + SUF
OUT = HOME + '/mut/out' + SUF
T = lambda a: '%d+' % a
F = lambda a: '%d-' % a


def write(path, ne, nc, init, nst, acc, trans):
    with open(path, 'w') as f:
        f.write('events %s\nclocks %d\ninit %d\nstates %d\nacc %s\n' % (' '.join('e%d' % i for i in range(ne)), nc, init, nst, ' '.join(map(str, acc))))
        for (s, d, lab, g, r) in trans:
            f.write('t %d %d | %s | %s | %s\n' % (s, d, ' '.join(lab), ' '.join(g), ' '.join(map(str, r))))


def rnd_tba(rng):
    nl = rng.randint(2, 6); nc = rng.randint(1, 3); ne = 3
    acc = sorted(rng.sample(range(nl), rng.randint(1, max(1, nl // 2))))
    trans = []
    for l in range(nl):
        for _ in range(rng.randint(1, 3)):
            d = rng.randrange(nl)
            r = rng.random()
            lab = [] if r < 0.15 else ([T(rng.randrange(ne))] if r < 0.8 else [F(rng.randrange(ne))])
            g = []
            for _ in range(rng.choice([0, 0, 1, 1, 2, 3])):
                c = rng.randrange(nc); op = rng.choice(['<=', '<', '>=', '>', '==']) if rng.random() < 0.8 else rng.choice(['<=', '>='])
                g.append('%d%s%d' % (c, op, rng.choice([0, 0, 1, 2, 3, 4, 5])))
            rs = [c for c in range(nc) if rng.random() < 0.35]
            trans.append((l, d, lab, g, rs))
    if DIRECTED:
        # structure-directed generation: add a twin of a guarded transition (same source, target, label, resets)
        # whose guard is the complement of one atom, so that the merge pass has complementary guards to combine
        comp = {'<': '>=', '<=': '>', '>=': '<', '>': '<=', '==': '<'}
        extra = []
        for (s0, d, lab, g, r) in trans:
            if g and rng.random() < 0.5:
                k = rng.randrange(len(g)); m = re.match(r'(\d+)(<=|<|>=|>|==)(\d+)$', g[k])
                if m:
                    op2 = comp[m.group(2)]
                    if MODE == '2' and m.group(2) in ('<', '>') and rng.random() < 0.5:
                        op2 = {'<': '>', '>': '<'}[m.group(2)]  # boundary twin: neither guard holds at x == c
                    g2 = list(g); g2[k] = m.group(1) + op2 + m.group(3)
                    extra.append((s0, d, lab, g2, r))
        trans = trans + extra
    return nl, nc, 0, acc, trans


def make_corpus():
    if os.path.isdir(CORP) and len(os.listdir(CORP)) >= N:
        return
    shutil.rmtree(CORP, ignore_errors=True); os.makedirs(CORP)
    rng = random.Random({'1': 20261111, '2': 20261112}.get(MODE, 20261110))
    kept = 0
    tmp = CORP + '_tmp'
    os.makedirs(tmp, exist_ok=True)
    while kept < N:
        nl, nc, init, acc, trans = rnd_tba(rng)
        p = os.path.join(tmp, 'x.tba'); write(p, 3, nc, init, nl, acc, trans)
        can = os.path.join(tmp, 'x.can'); to_canon.from_tba(p, can)
        out = subprocess.run([LC, can, can, '600', '7'], capture_output=True, text=True).stdout
        a = int(out.split('accA=')[1].split()[0]); pr = int(out.split('pairs=')[1].split()[0])
        if 0.03 <= a / pr <= 0.9:
            write(os.path.join(CORP, 'f%05d.tba' % kept), 3, nc, init, nl, acc, trans); kept += 1
    shutil.rmtree(tmp, ignore_errors=True)


def run_all(exe, outdir, files):
    os.makedirs(outdir, exist_ok=True)
    for p in files:
        name = os.path.basename(p)[:-4]
        for pol, flags in mut_lib.POLICIES:
            base = os.path.join(outdir, name + '.' + pol)
            sh([exe, '-o', base, '-dump', base + '.opt.tba'] + flags + [p], timeout=30)


def one(mid):
    files = sorted(glob.glob(CORP + '/*.tba'))
    gold = OUT + '/base'
    mdir = OUT + '/' + mid
    shutil.rmtree(mdir, ignore_errors=True)
    run_all(HOME + '/mut/exe/%s_tba_opt.exe' % mid, mdir, files)
    changed, bad, first = 0, 0, ''
    work = OUT + '/work_' + mid
    shutil.rmtree(work, ignore_errors=True); os.makedirs(work)
    for p in files:
        name = os.path.basename(p)[:-4]
        evs = events_of(p)
        a = None
        for pol, _ in mut_lib.POLICIES:
            base = os.path.join(mdir, name + '.' + pol)
            gbase = os.path.join(gold, name + '.' + pol)
            same = all(file_bytes(base + s) == file_bytes(gbase + s) for s in ('.xml', '.opt.tba'))
            if same:
                continue
            changed += 1
            if a is None:
                a = os.path.join(work, name + '.in.can'); to_canon.from_tba(p, a)
            kinds = [('xml', base + '.xml')] + ([('tba', base + '.opt.tba')] if pol == 'md' else [])
            mism = False
            for typ, f in kinds:
                if not os.path.exists(f):
                    mism = True; continue
                b = os.path.join(work, name + '.' + pol + '.' + typ + '.can')
                try:
                    (to_canon.from_xml(f, evs, b) if typ == 'xml' else to_canon.from_tba(f, b))
                except Exception:
                    mism = True; continue
                rc, out, err = sh([LC, a, b, str(WORDS), '17'], timeout=600)
                m = re.search(r'mismatch=(\d+)', out)
                if m and int(m.group(1)) > 0:
                    mism = True
            if mism:
                bad += 1
                if not first:
                    first = name
    shutil.rmtree(work, ignore_errors=True)
    line = '%s\t%d\t%d\t%s' % (mid, changed, bad, first)
    print(line, flush=True)
    return line


if __name__ == '__main__':
    make_corpus()
    files = sorted(glob.glob(CORP + '/*.tba'))
    shutil.rmtree(OUT + '/base', ignore_errors=True)
    run_all(HOME + '/mut/exe/base_tba_opt.exe', OUT + '/base', files)
    with Pool(8) as pool:
        lines = pool.map(one, IDS)
    os.makedirs(os.path.join(HERE, 'results'), exist_ok=True)
    with open(os.path.join(HERE, 'results', 'fuzz%s.tsv' % SUF), 'w') as f:
        f.write('id\tinputs_changed_output\tinputs_language_mismatch\tfirst_input\n')
        f.write('\n'.join(lines) + '\n')
    print('done')
