"""Ablation of the gateway assumption-guarantee case (reviewer request): four configurations of our pipeline plus CASAAL.
 none      -n 0 -all-copy                       (no optimization)
 optimizer -all-copy                            (verified optimization, default rounds)
 pruning   -all-copy -prune-split               (checked pruning after splitting)
 prune+reuse -all-copy -prune-split -alloc      (checked pruning and checked clock reuse)
For each k and the correct and faulty gateway: symbolic transitions, clocks, generation time, TChecker stored states,
search time, wall time and peak memory.  Usage (WSL): python3 ag_ablate.py [TCK_LIMIT]   Writes ag_ablate_results.tsv"""
import os, sys, tempfile, subprocess, csv, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.argv, ARGS = sys.argv[:1], sys.argv[1:]
sys.argv = ['x', ARGS[0] if ARGS else '120']
import run_tck as r, reqs

CONF = [('none', ['-n', '0', '-all-copy']), ('optimizer', ['-all-copy']),
        ('pruning', ['-all-copy', '-prune-split']), ('prune+reuse', ['-all-copy', '-prune-split', '-alloc'])]


def main():
    h = subprocess.run([r.EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\n')[0].split('\t')
    rows = [['k', 'configuration', 'sym_trans', 'clocks', 'gen_s', 'system', 'verdict', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for k in (2, 3, 4, 5):
        for sysname in ('ok', 'bad'):
            ours, cas, events = reqs.build('gateway', k, sysname)
            ev = ','.join(events)
            open(os.path.join(W, 'sys.xml'), 'w').write(reqs.system_xml('gateway', k, sysname))
            for name, flags in CONF:
                if name == 'none' and k >= 4:
                    rows.append([k, name, 'NA', 'NA', 'skipped', sysname, 'skipped', '', '', '', ''])
                    continue
                base = os.path.join(W, name.replace('+', '_'))
                rc, out, err, sec, _ = r.run([r.EXE, '-nopdf', '-stats'] + flags + ['-o', base, ours], cwd=W, timeout=300)
                if rc != 0:
                    rows.append([k, name, 'NA', 'NA', '>300', sysname, 'gen-fail', '', '', '', ''])
                    print(rows[-1], flush=True)
                    continue
                d = dict(zip(h, out.strip().split('\n')[-1].split('\t')))
                verdict, stored, search, wall, peak, _ = r.tck(ev, W, [f'A:{base}.xml', 'SYS:' + os.path.join(W, 'sys.xml')])
                rows.append([k, name, d['sym_trans'], d['exp_clocks'], '%.1f' % sec, sysname, verdict, stored, search, wall, peak])
                print(rows[-1], flush=True)
                csv.writer(open(os.path.join(HERE, 'ag_ablate_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    csv.writer(open(os.path.join(HERE, 'ag_ablate_results.tsv'), 'w', newline=''), delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)


if __name__ == '__main__':
    main()
