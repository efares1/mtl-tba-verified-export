"""Pilot: independent system (TChecker's train_gate example, not written by us) x property TBA.
Observed events: appr_i and leave_i of the Gate (via the Train/Gate sync vectors); stop/go/tau are unobserved.
Property: conjunction over i<=K of [](appr_i -> <>[<=D] leave_i), negated; the product is checked for emptiness
(tck-liveness -a couvscc).  Variants of the property automaton: mtl2tba without optimizer, with it, with checked
pruning + clock reuse.  Usage (WSL): python3 tg_pilot.py N K D [limit_s]"""
import os, re, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.abspath(os.path.join(HERE, '..'))
sys.path.insert(0, EV)
import tck_product as tp
EXE = os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
TCK = os.path.expanduser('~/local/bin/tck-liveness')
TGSH = os.path.expanduser('~/tools/tchecker/examples/train_gate.sh')
VARIANTS = [('ours_n0', ['-n', '0', '-all-copy']), ('ours', ['-all-copy']),
            ('ours_checked', ['-all-copy', '-prune-split', '-alloc'])]


def formula(N, B, D):
    A = ' & '.join(f'([](stop{i} -> <>[<={B}] go{i}))' for i in range(1, N + 1))
    G = ' & '.join(f'([](stop{i} -> <>[<={D}] leave{i}))' for i in range(1, N + 1))
    return f'!(({A}) -> ({G}))'


def run(cmd, cwd=None, timeout=None):
    inner = ' '.join("'%s'" % c.replace("'", "'\\''") for c in cmd)
    sh = f'ulimit -v {3*1024*1024}; exec /usr/bin/time -f "PEAKKB %M" {inner}'
    t0 = time.time()
    try:
        r = subprocess.run(['bash', '-c', sh], cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout', time.time() - t0, None
    m = re.search(r'PEAKKB (\d+)', r.stderr)
    return r.returncode, r.stdout, r.stderr, time.time() - t0, int(m.group(1)) if m else None


def build(system_text, auto, observed, out):
    """add the property process, Z and D to the system; observed = list of Gate events (appr1, leave1, ...)"""
    L = system_text.rstrip('\n').split('\n')
    # clocks
    extra = [f'clock:1:{auto.name}_{x}' for x in sorted(auto.clocks)] + ['clock:1:z', 'clock:1:t']
    ev_decl = ['event:dgo', 'event:dback']
    ev_decl += [f'event:{e}' for e in ('other',)]
    new = []
    new += ev_decl + extra + ['']
    # property process
    new.append(f'process:{auto.name}')
    for lid, (labels, inv, com) in auto.locs.items():
        attrs = []
        if lid == auto.init:
            attrs.append('initial:')
        if labels:
            attrs.append('labels:' + ','.join(labels))
        if inv:
            attrs.append('invariant:' + inv.replace(' ', ''))
        new.append(f'location:{auto.name}:l{lid}{{{":".join(attrs)}}}')
    for src, tgt, ev, g, resets, _ in auto.edges:
        attrs = []
        if g:
            attrs.append('provided:' + g.replace(' ', ''))
        if resets:
            attrs.append('do:' + ';'.join(f'{r}=0' for r in resets))
        new.append(f'edge:{auto.name}:l{src}:l{tgt}:{ev}{{{":".join(attrs)}}}')
    new.append('')
    new += ['process:Z', 'location:Z:z0{initial:}']
    for e in observed:
        new.append(f'edge:Z:z0:z0:{e}{{provided:z>0:do:z=0}}')
    new += ['', 'process:D', 'location:D:wait{initial:}', 'location:D:seen{}',
            'location:D:div{committed::labels:div}',
            'edge:D:seen:div:dback{provided:t>=1}', 'edge:D:div:wait:dgo{do:t=0}']
    for e in observed:
        new.append(f'edge:D:wait:seen:{e}{{}}')
        new.append(f'edge:D:seen:seen:{e}{{}}')
    new.append('')
    alpha = {x[2] for x in auto.edges}
    def ev_of(e):
        return e if (e in alpha or 'other' not in alpha) else 'other'
    # edges of the property on every observed event must exist: observed events not in the formula are 'other'
    # (mtl2tba XML has them under 'other'); the sync vector maps them
    out_lines = []
    for l in L:
        m = re.match(r'sync:(Train\d+@\w+):Gate@(\w+)$', l)
        if m and m.group(2) in observed:
            e = m.group(2)
            l = l + f':{auto.name}@{ev_of(e)}:Z@{e}:D@{e}'
        out_lines.append(l)
    # insert declarations after the system line, rest at the end (TChecker accepts any order of declarations)
    syncs = [l for l in out_lines if l.startswith('sync:')]
    rest = [l for l in out_lines if not l.startswith('sync:')]
    open(out, 'w').write('\n'.join(rest + [''] + new + syncs) + '\n')


def main():
    N, B, D = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
    limit = int(sys.argv[4]) if len(sys.argv) > 4 else 300
    W = tempfile.mkdtemp(dir="/tmp")
    sysf = run(['bash', TGSH, str(N)])[1]
    observed = [f'{e}{i}' for e in ('stop', 'go', 'leave') for i in range(1, N + 1)]
    f = formula(N, B, D)
    h = subprocess.run([EXE, '-stats-header'], capture_output=True, text=True).stdout.strip().split('\n')[0].split('\t')
    want = os.environ.get('VARS', 'ours_n0,ours,ours_checked,casaal').split(',')
    for name in want:
        if name == 'casaal':
            gv = os.path.join(HERE, 'casaal', f'tg_N{N}_B{B}_D{D}.gv')
            events = [f'{e}{i}' for e in ('stop', 'go', 'leave') for i in range(1, N + 1)]
            auto = tp.from_gv('P', gv, events)
            labels = ['div'] + auto.acc_labels
            d = {'exp_locs': len(auto.locs), 'sym_trans': len(auto.edges), 'exp_clocks': len(auto.clocks)}
            gsec = 0.0
        else:
            flags = dict(VARIANTS)[name]
            base = os.path.join(W, name)
            rc, out, err, gsec, _ = run([EXE, '-nopdf', '-stats'] + flags + ['-o', base, f], cwd=W, timeout=600)
            if rc != 0:
                print(name, 'gen-fail', err[-200:]); continue
            d = dict(zip(h, out.strip().split(chr(10))[-1].split(chr(9))))
            auto = tp.from_xml('P', base + '.xml')
            labels = ['div', 'accP']
        m = os.path.join(W, name + '.tck')
        build(sysf, auto, observed, m)
        rc, o, e2, wall, peak = run([TCK, '-a', 'couvscc', '-l', ','.join(labels), m], timeout=limit)
        v = re.search(r'^CYCLE (true|false)', o, re.M)
        verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('timeout' if rc == 124 else 'err:' + e2[-150:])
        g = lambda k: (re.search(r'^%s (\S+)' % k, o, re.M) or [None, 'NA'])[1]
        print(chr(9).join(map(str, [N, B, D, name, d['exp_locs'], d['sym_trans'], d['exp_clocks'], '%.1f' % gsec, verdict,
                                  g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), '%.1f' % wall, peak // 1024 if peak else 'NA'])), flush=True)


if __name__ == '__main__':
    main()
