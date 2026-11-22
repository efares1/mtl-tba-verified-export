"""Modular variant of compose.py: each assumption A_i = [](a_i -> <>[<=3] b_i) is translated alone and the product is
S x A_1 x ... x A_k x N (TChecker, generalized acceptance), instead of translating the conjunction.
Usage (WSL): python3 compose_sep.py [LIMIT]   Writes compose_sep_results.tsv"""
import os, sys, tempfile, csv, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
sys.argv = ['x', ARGS[0] if ARGS else '120']
import run_tck as r, compose as c

def main():
    rows = [['k', 'variant', 'system', 'verdict', 'expected', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for k in [int(x) for x in os.environ.get('KS', '2,3,4,5,6').split(',')]:
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done']
        ev = ','.join(events)
        for name, flags in (('sep', ['-all-copy']), ('sep_checked', ['-all-copy', '-prune-split', '-alloc'])):
            autos = []
            for i in range(1, k + 1):
                a = c.gen_ours(W, name + str(i), flags, f'([](a{i} -> <>[<=3] b{i}))', f'A{i}')
                autos.append(f'A{i}:{a[0]}')
            n = c.gen_ours(W, name, flags, c.NEG, 'N')
            for sysname, d in (('ok', 2), ('bad', 4)):
                open(os.path.join(W, 'sys.xml'), 'w').write(c.system_xml(k, d))
                v, st, se, wall, peak, _ = r.tck(ev, W, autos + [f'N:{n[0]}', 'SYS:' + os.path.join(W, 'sys.xml')])
                rows.append([k, name, sysname, v, 'empty' if sysname == 'ok' else 'nonempty', st, se, wall, peak])
                print(rows[-1], flush=True)
                csv.writer(open(os.path.join(HERE, 'compose_sep_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)

if __name__ == '__main__':
    main()
