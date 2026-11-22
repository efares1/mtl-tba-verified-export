"""Slicing by the tool: one automaton for A_1 & ... & A_k & !G, translated without and with `-slice-system sys.xml`
(the tool reads from the system file that it constrains only b1 and done, and checks that every location ignores the other events), then composed with the system.
Usage (WSL): python3 compose_toolslice.py [LIMIT]   Writes compose_toolslice_results.tsv"""
import os, sys, tempfile, csv, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
sys.argv = ['x', ARGS[0] if ARGS else '120']
import run_tck as r, compose as c
sys.path.insert(0, r.EV)
import tck_product

def main():
    rows = [['k', 'variant', 'sym_trans', 'gen_s', 'system', 'verdict', 'expected', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for k in [int(x) for x in os.environ.get('KS', '2,3,4,5,6,8,10').split(',')]:
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done']
        ev = ','.join(events)
        form = c.assume(k) + ' & ' + c.NEG
        open(os.path.join(W, 'sys.xml'), 'w').write(c.system_xml(k, 2))
        for name, flags in (('unsliced', ['-all-copy']), ('sliced', ['-all-copy', '-slice-system', os.path.join(W, 'sys.xml')])):
            if name == 'unsliced' and k > 5:
                continue
            a = c.gen_ours(W, name, flags, form, 'X', timeout=300)
            if a is None:
                rows.append([k, name, 'NA', 'NA', '-', 'gen-fail', '', '', '', '', '']); continue
            for sysname, d in (('ok', 2), ('bad', 4)):
                open(os.path.join(W, 'sys.xml'), 'w').write(c.system_xml(k, d))
                if name == 'sliced':
                    dl = [f'{x}{i}' for i in range(2, k + 1) for x in 'ab']
                    assert tck_product.ignores(os.path.join(W, 'sys.xml'), dl), 'system does not ignore the sliced letters'
                v, st, se, wall, peak, _ = r.tck(ev, W, [f'X:{a[0]}', 'SYS:' + os.path.join(W, 'sys.xml')])
                rows.append([k, name, a[2], '%.1f' % a[3], sysname, v, 'empty' if sysname == 'ok' else 'nonempty', st, se, wall, peak])
                print(rows[-1], flush=True)
                csv.writer(open(os.path.join(HERE, 'compose_toolslice_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)

if __name__ == '__main__':
    main()
