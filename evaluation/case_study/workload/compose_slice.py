"""Slicing of assume-guarantee checks: assumptions whose events are disjoint from the guarantee and from the events the
system constrains are dropped (sound when each dropped assumption is satisfied by a word without its events and the system
accepts those events in every location; see NextPaper note).  Here the system only synchronizes on b1 and done.
Usage (WSL): python3 compose_slice.py [LIMIT]   Writes compose_slice_results.tsv"""
import os, sys, tempfile, csv, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
sys.argv = ['x', ARGS[0] if ARGS else '120']
import run_tck as r, compose as c

def main():
    rows = [['k', 'kept_assumptions', 'system', 'verdict', 'expected', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for k in [int(x) for x in os.environ.get('KS', '2,3,4,5,6,8').split(',')]:
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done']
        ev = ','.join(events)
        a = c.gen_ours(W, 'sl', ['-all-copy'], '([](a1 -> <>[<=3] b1))', 'A1')
        n = c.gen_ours(W, 'sl', ['-all-copy'], c.NEG, 'N')
        for sysname, d in (('ok', 2), ('bad', 4)):
            open(os.path.join(W, 'sys.xml'), 'w').write(c.system_xml(k, d))
            v, st, se, wall, peak, _ = r.tck(ev, W, [f'A1:{a[0]}', f'N:{n[0]}', 'SYS:' + os.path.join(W, 'sys.xml')])
            rows.append([k, 1, sysname, v, 'empty' if sysname == 'ok' else 'nonempty', st, se, wall, peak])
            print(rows[-1], flush=True)
    csv.writer(open(os.path.join(HERE, 'compose_slice_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)

if __name__ == '__main__':
    main()
