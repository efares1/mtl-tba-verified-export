"""Assume-guarantee case study with TChecker (timed Buechi emptiness, tck-liveness -a couvscc).
Requirement: (a1 -> <>[<=5] b1) & ... & (ak -> <>[<=5] bk)  ->  [](a1 -> <>[<=5] done)   (k = 2..5)
System: a single-threaded gateway; channel i is answered after 1 to 2 time units, after the answer on
channel 1 a downstream component emits 'done' after 1 to 2 (correct) or 1 to 6 (faulty) time units.
The negated requirement is translated by mtl2tba (all-copy export, without the optimizer, with it, and with the checked
pruning and clock reuse) and by CASAAL (casaal/agK.gv, made by gen_casaal_ag.py); each automaton is composed with the
system and TChecker decides emptiness.  Expected: empty for the correct system, non-empty for the faulty one.
Usage (WSL): python3 ag_tck.py [LIMIT_SECONDS]      Writes ag_tck_results.tsv."""
import os, re, subprocess, sys, tempfile, csv, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.abspath(os.path.join(HERE, '..', '..'))
EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.environ.get('TCK', os.path.expanduser('~/local/bin/tck-liveness'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
VARIANTS = [('ours_n0', ['-n', '0', '-all-copy']), ('ours', ['-all-copy']), ('ours_checked', ['-all-copy', '-prune-split', '-alloc'])]


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def system_xml(k, dmax):
    s = '<nta><template><name>Property</name><declaration>clock x0;</declaration>\n<location id="i"><name>Idle</name></location>\n'
    for j in range(1, k + 1):
        s += f'<location id="b{j}"><name>Busy{j}</name><label kind="invariant">x0 &lt;= 2</label></location>\n'
    s += f'<location id="d"><name>Done</name><label kind="invariant">x0 &lt;= {dmax}</label></location>\n<init ref="i"/>\n'
    for j in range(1, k + 1):
        s += (f'<transition><source ref="i"/><target ref="b{j}"/><label kind="synchronisation">a{j}?</label>'
              f'<label kind="assignment">x0 = 0</label></transition>\n')
        tgt = 'd' if j == 1 else 'i'
        s += (f'<transition><source ref="b{j}"/><target ref="{tgt}"/><label kind="guard">x0 &gt;= 1</label>'
              f'<label kind="synchronisation">b{j}?</label><label kind="assignment">x0 = 0</label></transition>\n')
    s += ('<transition><source ref="d"/><target ref="i"/><label kind="guard">x0 &gt;= 1</label>'
          '<label kind="synchronisation">done?</label><label kind="assignment">x0 = 0</label></transition>\n')
    return s + '</template></nta>\n'


def run_tck(events, W, args):
    rc, lab, err = sh([sys.executable, os.path.join(EV, 'tck_product.py'), os.path.join(W, 'm.tck'), events] + args)
    if rc != 0:
        return ('convert-error', 'NA', 'NA', 'NA')
    rc, out, err = sh([TCK, '-a', 'couvscc', '-l', lab.strip(), os.path.join(W, 'm.tck')], timeout=LIMIT)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else 'timeout'
    g = lambda key: (re.search(r'^%s (\S+)' % key, out, re.M) or [None, 'NA'])[1]
    return (verdict, g('STORED_STATES'), g('VISITED_TRANSITIONS'), g('RUNNING_TIME_SECONDS'))


def main():
    h = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\t')
    rows = [['k', 'automaton', 'locs', 'sym_trans', 'clocks', 'system', 'verdict', 'expected', 'stored', 'visited_trans', 'seconds']]
    W = tempfile.mkdtemp()
    for k in (2, 3, 4, 5):
        assume = ' & '.join(f'[](a{i} -> <>[<=5] b{i})' for i in range(1, k + 1))
        neg = f'!(({assume}) -> [](a1 -> <>[<=5] done))'
        events = ','.join([f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done'])
        autos = []
        for name, flags in VARIANTS:
            base = os.path.join(W, f'ag{k}_{name}')
            rc, out, err = sh([EXE, '-nopdf', '-stats'] + flags + ['-o', base, neg], cwd=W, timeout=LIMIT)
            if rc != 0:
                rows.append([k, name, 'NA', 'NA', 'NA', '-', 'gen-fail', '', '', '', '']); print(rows[-1], flush=True); continue
            d = dict(zip(h, out.strip().split('\n')[-1].split('\t')))
            autos.append((name, f'A:{base}.xml', d['exp_locs'], d['sym_trans'], d['exp_clocks']))
        gv = os.path.join(HERE, 'casaal', f'ag{k}.gv')
        if os.path.exists(gv):
            n, e, c = [x.strip() for x in open(os.path.join(HERE, 'casaal', 'sizes.tsv')).read().split('\n')[k - 1].split('\t')[3:6]]
            autos.append(('casaal', f'A:{gv}', n, e, c))
        for sysname, dmax in (('ok', 2), ('bad', 6)):
            open(os.path.join(W, 'sys.xml'), 'w').write(system_xml(k, dmax))
            for name, arg, locs, trans, clocks in autos:
                verdict, stored, vt, sec = run_tck(events, W, [arg, 'SYS:' + os.path.join(W, 'sys.xml')])
                expected = 'empty' if sysname == 'ok' else 'nonempty'
                rows.append([k, name, locs, trans, clocks, sysname, verdict, expected, stored, vt, sec])
                print(rows[-1], flush=True)
    with open(os.path.join(HERE, 'ag_tck_results.tsv'), 'w', newline='') as f:
        csv.writer(f, delimiter='\t').writerows(rows)
    shutil.rmtree(W, ignore_errors=True)


if __name__ == '__main__':
    main()
