"""Assume-guarantee check with the assumptions as automata (TChecker, tck-liveness -a couvscc).
A component receives the answer b1 and emits `done` within 1..D time units; the environment is free.  Guarantee:
[](a1 -> <>[<=5] done).  It holds only under the assumptions A_k = /\\_i [](a_i -> <>[<=3] b_i), so the product
S x A_k x N is checked for emptiness, N being the automaton of the negated guarantee (D = 2: empty; D = 4: non-empty).
A_k and N come from mtl2tba (without the optimizer, with it, with checked pruning and clock reuse) or from CASAAL
(through our importer; the compact route through the tba format cannot be used, because CASAAL prints no acceptance mark on positive forms).
Usage (WSL): python3 compose.py [TCK_LIMIT_SECONDS]      Writes compose_results.tsv."""
import os, re, sys, tempfile, csv, shutil, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
LIMIT0 = ARGS[0] if ARGS else '120'
sys.argv = ['x', LIMIT0]
import run_tck as r

NEG = '!([](a1 -> <>[<=5] done))'


def assume(k):
    return ' & '.join(f'([](a{i} -> <>[<=3] b{i}))' for i in range(1, k + 1))


def system_xml(k, d):
    ev_a = [f'a{i}' for i in range(1, k + 1)]
    s = '<nta><template><name>Property</name><declaration>clock x0;</declaration>\n'
    s += '<location id="i"><name>Idle</name></location>\n'
    s += f'<location id="w"><name>Wait</name><label kind="invariant">x0 &lt;= {d}</label></location>\n<init ref="i"/>\n'

    def tr(src, tgt, ev, guard=None, reset=False):
        t = f'<transition><source ref="{src}"/><target ref="{tgt}"/>'
        if guard:
            t += f'<label kind="guard">{guard}</label>'
        t += f'<label kind="synchronisation">{ev}?</label>'
        if reset:
            t += '<label kind="assignment">x0 = 0</label>'
        return t + '</transition>\n'
    for e in ev_a:
        s += tr('i', 'i', e) + tr('w', 'w', e)
    for j in range(2, k + 1):
        s += tr('i', 'i', f'b{j}') + tr('w', 'w', f'b{j}')
    s += tr('i', 'w', 'b1', reset=True) + tr('w', 'w', 'b1')
    s += tr('w', 'i', 'done', 'x0 &gt;= 1')
    return s + '</template></nta>\n'


def gen_ours(W, name, flags, formula, tag, timeout=300):
    base = os.path.join(W, f'{tag}_{name}')
    rc, out, err, sec, _ = r.run([r.EXE, '-nopdf', '-stats'] + flags + ['-o', base, formula], cwd=W, timeout=timeout)
    if rc != 0:
        return None
    h = subprocess.run([r.EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\n')[0].split('\t')
    d = dict(zip(h, out.strip().split('\n')[-1].split('\t')))
    return base + '.xml', int(d['exp_locs']), int(d['sym_trans']), sec


def gen_casaal(W, gv, flags, tag, ev):
    tba = os.path.join(W, f'{tag}.tba')
    rc = r.run([sys.executable, os.path.join(r.EV, 'casaal_to_tba.py'), gv, tba, ev])[0]
    if rc != 0:
        return None
    base = os.path.join(W, f'{tag}_x')
    rc, out, err, sec, _ = r.run([r.TBAOPT, '-stats'] + flags + ['-o', base, tba], cwd=W, timeout=300)
    if rc != 0:
        return None
    return base + '.xml', sec


def main():
    rows = [['k', 'variant', 'locs', 'sym_trans', 'gen_s', 'system', 'verdict', 'expected', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for k in [int(x) for x in os.environ.get('KS', '2,3,4,5').split(',')]:
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done']
        ev = ','.join(events)
        cg = lambda n: os.path.join(HERE, 'casaal', n + '.gv')
        variants = []
        for name, flags in (('ours_n0', ['-n', '0', '-all-copy']), ('ours', ['-all-copy']),
                            ('ours_checked', ['-all-copy', '-prune-split', '-alloc'])):
            if name == 'ours_n0' and k >= 4:
                rows.append([k, name, 'NA', 'NA', 'skipped', '-', 'skipped', '', '', '', '', ''])
                continue
            a = gen_ours(W, name, flags, assume(k), 'A')
            n = gen_ours(W, name, flags, NEG, 'N')
            variants.append((name, a, n))
        variants.append(('casaal', ('G:' + cg(f'A{k}'), None, None, 0), ('G:' + cg('N'), None, None, 0)))
        for sysname, d in (('ok', 2), ('bad', 4)):
            open(os.path.join(W, 'sys.xml'), 'w').write(system_xml(k, d))
            for name, a, n in variants:
                if a is None or n is None:
                    rows.append([k, name, 'NA', 'NA', 'NA', sysname, 'gen-fail', '', '', '', '', ''])
                    print(rows[-1], flush=True)
                    continue
                locs = (a[1] + n[1]) if a[1] is not None else 'NA'
                trans = (a[2] + n[2]) if a[2] is not None else 'NA'
                gsec = '%.1f' % (a[3] + n[3])
                pa = a[0][2:] if a[0].startswith('G:') else a[0]
                pn = n[0][2:] if n[0].startswith('G:') else n[0]
                verdict, stored, search, wall, peak, _ = r.tck(ev, W, [f'A:{pa}', f'N:{pn}', 'SYS:' + os.path.join(W, 'sys.xml')])
                rows.append([k, name, locs, trans, gsec, sysname, verdict, 'empty' if sysname == 'ok' else 'nonempty',
                             stored, search, wall, peak])
                print(rows[-1], flush=True)
                r.csv.writer(open(os.path.join(HERE, 'compose_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    r.csv.writer(open(os.path.join(HERE, 'compose_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)


if __name__ == '__main__':
    main()
