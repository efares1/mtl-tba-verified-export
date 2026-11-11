"""Invariant-only baselines and non-empty products for TChecker.

Arms (automaton of the NEGATED requirement given to tck-liveness):
  ours         mtl2tba default (optimizer + max-delay export)
  ours_n0      mtl2tba -n 0
  ours_noinv   ours with every location invariant removed after export
  casaal       CASAAL's own automaton (no invariants)
  casaal_inv   CASAAL's automaton plus a TRIVIAL unverified invariant step: at a
               location, clock x gets x<=max(k) if every outgoing edge has an upper
               bound x<k or x<=k (no propagation, no splitting)
  casaal_exp   CASAAL's automaton imported and passed through our export (-n 0)
Workloads (the system composed with the arm):
  ref       the requirement's own automaton (all-copy export), as in the paper: empty product
  free      a system that allows every event at every time (non-empty unless the
            negation is unsatisfiable together with strictly increasing divergent time)
  resp_ok / resp_bad   hand-written response system for R1..Rn (ok answers within 2,
            bad never answers b1): expected empty / non-empty
Usage (WSL): python3 run_baselines.py LIMIT WORKLOAD ID...   -> baselines_<WORKLOAD>.tsv"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, '..')
sys.path.insert(0, EV)
import tck_product as tp
EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OPT = os.environ.get('OPT', os.path.expanduser('~/tool_copy/_build/default/src/tba_opt.exe'))
PRUNE = os.environ.get('PRUNE_FLAG', '-prune')  # -prune (plain) or -prune-split (split by cells first)
TCK = os.path.expanduser('~/local/bin/tck-liveness')
LIMIT = int(sys.argv[1]); WORKLOAD = sys.argv[2]; ONLY = sys.argv[3:]
AC = ['-all-copy'] if os.environ.get('ALLCOPY') else []
OUT = os.path.join(HERE, 'baselines_%s%s%s.tsv' % (WORKLOAD, '_allcopy' if AC else '', os.environ.get('OUTSUF', '')))


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def strip_inv(a):
    for k, (lab, inv, com) in list(a.locs.items()):
        a.locs[k] = (lab, None, com)


UB = re.compile(r'^(\w+)(<=|<)(\d+)$')


def trivial_inv(a):
    out = {}
    for (src, tgt, ev, g, resets, _) in a.edges:
        out.setdefault(src, []).append(g)
    for lid, (lab, inv, com) in list(a.locs.items()):
        edges = out.get(lid, [])
        if not edges or com:
            continue
        clocks = set()
        for g in edges:
            for atom in (g or '').split('&&'):
                m = UB.match(atom.strip())
                if m:
                    clocks.add(m.group(1))
        parts = []
        for c in sorted(clocks):
            bounds = []
            for g in edges:
                bs = []
                for atom in (g or '').split('&&'):
                    m = UB.match(atom.strip())
                    if m and m.group(1) == c:
                        bs.append(int(m.group(3)))
                if not bs:
                    bounds = None
                    break
                bounds.append(min(bs))
            if bounds:
                parts.append('%s<=%d' % (c, max(bounds)))
        if parts:
            a.locs[lid] = (lab, '&&'.join(parts), com)


def product(events, W, first, arm_aut):
    autos = [first, arm_aut]
    labels = ['div']
    for a in autos:
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        if a.state_based and not ls:
            ls = ['acc' + a.name]
            a.locs['unreach'] = (ls, None, False)
        labels += ls
    tp.write(os.path.join(W, 'm.tck'), autos, events)
    return ','.join(labels)


def run_tck(W, labels):
    rc, out, err = sh(['/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc',
                       '-l', labels, os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('error' if 'ERROR' in out + err else 'timeout')
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), g('PEAKKB', err)


def free_system(events, path):
    chans = ', '.join(events + ['other'])
    L = ['<?xml version="1.0" encoding="utf-8"?>', '<nta>', '  <declaration>chan %s;</declaration>' % chans,
         '  <template>', '    <name>Sys</name>', '    <declaration>clock y, z;</declaration>',
         '    <location id="s0" x="0" y="0"><name>Idle</name></location>', '    <init ref="s0"/>']
    for e in events + ['other']:
        L.append('    <transition><source ref="s0"/><target ref="s0"/><label kind="guard">z &gt; 0</label>'
                 '<label kind="synchronisation">%s!</label><label kind="assignment">z = 0</label></transition>' % e)
    L += ['  </template>', '  <system>Process = Sys();system Process;</system>', '</nta>']
    open(path, 'w').write('\n'.join(L) + '\n')


hdr = ['id', 'workload', 'arm', 'verdict', 'stored', 'seconds', 'peak_kb']
recs = [l.rstrip('\n').split('\t') for l in open(os.path.join(EV, 'formulas.tsv'), encoding='utf8')
        if l.strip() and not l.startswith('#')]
new = not os.path.exists(OUT)
with open(OUT, 'a', encoding='utf8') as o:
    if new:
        o.write('\t'.join(hdr) + '\n')
    for rec in recs:
        if len(rec) < 4:
            continue
        i, desc, ours, cas = rec[:4]
        if i not in ONLY:
            continue
        gv = os.path.join(EV, 'casaal_out' if WORKLOAD in ('posbad', 'posbadall') else 'casaal_out_neg', i + '.gv')
        FORM = '%s' if WORKLOAD in ('posbad', 'posbadall') else '!(%s)'
        events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
        W = tempfile.mkdtemp()
        try:
            if WORKLOAD == 'ref':
                rc, _, _ = sh([EXE, '-nopdf', '-all-copy', '-o', os.path.join(W, 'ref'), ours], cwd=W, timeout=LIMIT)
                if rc != 0:
                    print(i, 'ref failed')
                    continue
                mk_first = lambda: tp.from_xml('REF', os.path.join(W, 'ref.xml'))
            else:
                if WORKLOAD == 'free':
                    free_system(events, os.path.join(W, 'sys0.xml'))
                else:
                    m = re.match(r'R(\d+)$', i)
                    if not m:
                        print(i, 'not a response pattern')
                        continue
                    sh([sys.executable, os.path.join(EV, 'make_resp_system.py'), m.group(1), os.path.join(W, 'sys0.xml')]
                       + (['bad'] if WORKLOAD in ('resp_bad', 'posbad') else ['badall'] if WORKLOAD == 'posbadall' else []))
                sh([sys.executable, os.path.join(EV, 'tck_normalize_system.py'), os.path.join(W, 'sys0.xml'),
                    os.path.join(W, 'sys.xml')])
                mk_first = lambda: tp.from_xml('SYS', os.path.join(W, 'sys.xml'))
            arms = {}
            for name, args in (('ours', AC), ('ours_n0', ['-n', '0'] + AC)):
                rc, _, _ = sh([EXE, '-nopdf', '-o', os.path.join(W, name)] + args + [FORM % ours], cwd=W, timeout=LIMIT)
                arms[name] = (lambda n=name: tp.from_xml('NEG', os.path.join(W, n + '.xml'))) if rc == 0 else None
            if arms.get('ours'):
                def noinv():
                    a = tp.from_xml('NEG', os.path.join(W, 'ours.xml'))
                    strip_inv(a)
                    return a
                arms['ours_noinv'] = noinv
            if os.path.exists(gv):
                arms['casaal'] = lambda: tp.from_gv('NEG', gv, events)

                def cinv():
                    a = tp.from_gv('NEG', gv, events)
                    trivial_inv(a)
                    return a
                arms['casaal_inv'] = cinv
                tba = os.path.join(W, 'c.tba')
                rc, _, _ = sh([sys.executable, os.path.join(EV, os.environ.get('CAS2TBA', 'casaal_to_tba.py')), gv, tba, ','.join(events)])
                if rc == 0:
                    rc, _, _ = sh([OPT, '-o', os.path.join(W, 'cexp'), '-n', '0'] + AC + [tba], timeout=LIMIT)
                    rcp, _, errp = sh([OPT, '-o', os.path.join(W, 'cprune'), '-n', '0', PRUNE] + AC + [tba], timeout=LIMIT)
                    if rcp == 0 and 'accepted by the checker: true' in errp:
                        arms['casaal_pruned'] = lambda: tp.from_xml('NEG', os.path.join(W, 'cprune.xml'))
                    rcq, _, errq = sh([EXE, '-nopdf', '-v', PRUNE, '-o', os.path.join(W, 'oprune')] + AC + [FORM % ours], cwd=W, timeout=LIMIT)
                    if rcq == 0 and 'accepted by the checker: true' in errq:
                        arms['ours_pruned'] = lambda: tp.from_xml('NEG', os.path.join(W, 'oprune.xml'))
                    if rc == 0:
                        arms['casaal_exp'] = lambda: tp.from_xml('NEG', os.path.join(W, 'cexp.xml'))

                        def cexp_noinv():
                            a = tp.from_xml('NEG', os.path.join(W, 'cexp.xml'))
                            strip_inv(a)
                            return a
                        arms['casaal_exp_noinv'] = cexp_noinv
            for name in (os.environ.get('ARMS') or 'ours,ours_n0,ours_noinv,casaal,casaal_inv,casaal_exp,casaal_exp_noinv').split(','):
                mk = arms.get(name)
                if mk is None:
                    row = [i, WORKLOAD, name, 'NA', 'NA', 'NA', 'NA']
                else:
                    labels = product(events, W, mk_first(), mk())
                    row = [i, WORKLOAD, name] + list(run_tck(W, labels))
                o.write('\t'.join(map(str, row)) + '\n')
                o.flush()
                print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
