"""Broader assumption-guarantee workload under TChecker (timed Buechi emptiness, tck-liveness -a couvscc).
For every family and size of reqs.py and for a correct and a faulty system, the negated requirement is
translated by mtl2tba (without the optimizer, with it, with checked pruning and clock reuse; all-copy export) and by CASAAL
(casaal/*.gv), composed with the system, and decided by TChecker under a time limit and a 3 GB memory limit.
Expected verdict: empty for the correct system, non-empty for the faulty one.
Usage (WSL): python3 run_tck.py [TCK_LIMIT_SECONDS]      Writes workload_results.tsv."""
import os, re, subprocess, sys, tempfile, csv, shutil, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import reqs
EV = os.path.abspath(os.path.join(HERE, '..', '..'))
EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TBAOPT = os.environ.get('TBAOPT', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'tba_opt.exe'))
TCK = os.environ.get('TCK', os.path.expanduser('~/local/bin/tck-liveness'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 120
VARIANTS = [('ours_n0', ['-n', '0', '-all-copy']), ('ours', ['-all-copy']),
            ('ours_checked', ['-all-copy', '-prune-split', '-alloc'])]
MEM_KB = 3 * 1024 * 1024


def run(cmd, cwd=None, timeout=None, mem=True):
    """returns (returncode, stdout, stderr, seconds, peak_kb)"""
    inner = ' '.join("'%s'" % c.replace("'", "'\\''") for c in cmd)
    sh = f'ulimit -v {MEM_KB}; exec /usr/bin/time -f "PEAKKB %M" {inner}'
    t0 = time.time()
    try:
        r = subprocess.run(['bash', '-c', sh], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout', time.time() - t0, None
    m = re.search(r'PEAKKB (\d+)', r.stderr)
    return r.returncode, r.stdout, r.stderr, time.time() - t0, int(m.group(1)) if m else None


def tck(events, W, args):
    rc, lab, err, _, _ = run([sys.executable, os.path.join(EV, 'tck_product.py'), os.path.join(W, 'm.tck'), events] + args)
    if rc != 0:
        return ('convert-error', 'NA', 'NA', 'NA', 'NA', 'NA')
    rc, out, err, wall, peak = run([TCK, '-a', 'couvscc', '-l', lab.strip().split('\n')[0], os.path.join(W, 'm.tck')], timeout=LIMIT)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    if v:
        verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)]
    else:
        verdict = 'timeout' if rc == 124 else 'memout'
    g = lambda key: (re.search(r'^%s (\S+)' % key, out, re.M) or [None, 'NA'])[1]
    return (verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), '%.2f' % wall, peak // 1024 if peak else 'NA', '')


def save(rows):
    with open(os.path.join(HERE, 'workload_results.tsv'), 'w', newline='') as f:
        csv.writer(f, delimiter='	').writerows(rows)


def main():
    h = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\n')[0].split('\t')
    rows = [['family', 'k', 'automaton', 'locs', 'sym_trans', 'clocks', 'gen_s', 'system', 'verdict', 'expected', 'stored', 'search_s', 'wall_s', 'peak_mb']]
    W = tempfile.mkdtemp()
    for fam, k in reqs.ALL:
        for sysname in ('ok', 'bad'):
            ours, cas, events = reqs.build(fam, k, sysname)
            ev = ','.join(events)
            open(os.path.join(W, 'sys.xml'), 'w').write(reqs.system_xml(fam, k, sysname))
            autos = []
            for name, flags in VARIANTS:
                if name == 'ours_n0' and k >= 4:
                    rows.append([fam, k, name, 'NA', 'NA', 'NA', 'skipped', sysname, 'skipped', '', '', '', '', ''])
                    save(rows)
                    continue
                base = os.path.join(W, f'{name}')
                rc, out, err, sec, _ = run([EXE, '-nopdf', '-stats'] + flags + ['-o', base, ours], cwd=W, timeout=300)
                if rc != 0:
                    rows.append([fam, k, name, 'NA', 'NA', 'NA', 'NA' if rc != 124 else '>300', sysname, 'gen-fail', '', '', '', '', ''])
                    print(rows[-1], flush=True)
                    continue
                d = dict(zip(h, out.strip().split('\n')[-1].split('\t')))
                autos.append((name, f'A:{base}.xml', d['exp_locs'], d['sym_trans'], d['exp_clocks'], '%.1f' % sec))
            gv = os.path.join(HERE, 'casaal', f'{fam}{k}_{sysname}.gv')
            if os.path.exists(gv):
                sz = [l.split('\t') for l in open(os.path.join(HERE, 'casaal', 'sizes.tsv')).read().strip().split('\n')[1:]]
                n, e, c, s = next(((r[5], r[6], r[7], r[4]) for r in sz if r[0] == fam and r[1] == str(k) and r[2] == sysname), ('NA',) * 4)
                autos.append(('casaal', f'A:{gv}', n, e, c, s))
                tba = os.path.join(W, 'c.tba')
                rc, _, _, _, _ = run([sys.executable, os.path.join(EV, 'casaal_to_tba.py'), gv, tba, ev])
                if rc == 0:
                    rc, _, _, _, _ = run([TBAOPT, '-n', '0', '-all-copy', '-o', os.path.join(W, 'cx'), tba], cwd=W, timeout=300)
                    if rc == 0:
                        autos.append(('casaal_x', f'A:{W}/cx.xml', n, e, c, s))
            for name, arg, locs, trans, clocks, gsec in autos:
                verdict, stored, search, wall, peak, _ = tck(ev, W, [arg, 'SYS:' + os.path.join(W, 'sys.xml')])
                expected = 'empty' if sysname == 'ok' else 'nonempty'
                rows.append([fam, k, name, locs, trans, clocks, gsec, sysname, verdict, expected, stored, search, wall, peak])
                print(rows[-1], flush=True)
                save(rows)
    save(rows)
    shutil.rmtree(W, ignore_errors=True)


if __name__ == '__main__':
    main()
