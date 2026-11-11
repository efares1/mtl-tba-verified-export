"""Does the optimizer change what TChecker explores, on families where it removes many transitions?
For each formula of scaling_formulas.tsv (id <TAB> description <TAB> MTL formula) the NEGATED requirement is translated with the
default optimizer ('ours') and with -n 0 ('ours_n0'), exported with the same policy, composed with a free system (every event at
every time), and checked with tck-liveness -a couvscc.  Records the automaton size (locations, transitions, clocks),
the verdict, the stored states, TChecker's running time and peak memory.
Usage (WSL): python3 run_scaling.py LIMIT ID...   -> scaling_free.tsv   (env ALLCOPY=1 for the all-copy export)"""
import os, re, subprocess, sys, tempfile, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, '..')
sys.path.insert(0, EV)
import tck_product as tp
EXE = os.environ.get('EXE', os.path.join(EV, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
LIMIT = int(sys.argv[1]); ONLY = sys.argv[2:]
AC = ['-all-copy'] if os.environ.get('ALLCOPY') else []
OUT = os.path.join(HERE, 'scaling_free%s.tsv' % ('_allcopy' if AC else ''))


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


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


def run_tck(W, labels):
    rc, out, err = sh(['/usr/bin/time', '-f', 'PEAKKB %M', 'timeout', '-s', 'KILL', str(LIMIT), TCK, '-a', 'couvscc',
                       '-l', labels, os.path.join(W, 'm.tck')], timeout=LIMIT + 30)
    v = re.search(r'^CYCLE (true|false)', out, re.M)
    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else ('error' if 'ERROR' in out + err else 'timeout')
    g = lambda k, s=out: (re.search(r'^%s (\S+)' % k, s, re.M) or [None, 'NA'])[1]
    return verdict, g('STORED_STATES'), g('RUNNING_TIME_SECONDS'), g('PEAKKB', err)


hdr = ['id', 'arm', 'locations', 'transitions', 'clocks', 'verdict', 'stored', 'seconds', 'peak_kb']
recs = [l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, 'scaling_formulas.tsv'), encoding='utf8')
        if l.strip() and not l.startswith('#')]
new = not os.path.exists(OUT)
with open(OUT, 'a', encoding='utf8') as o:
    if new:
        o.write('\t'.join(hdr) + '\n')
    for rec in recs:
        i, desc, ours = rec[:3]
        if ONLY and i not in ONLY:
            continue
        events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
        W = tempfile.mkdtemp()
        try:
            free_system(events, os.path.join(W, 'sys0.xml'))
            sh([sys.executable, os.path.join(EV, 'tck_normalize_system.py'), os.path.join(W, 'sys0.xml'), os.path.join(W, 'sys.xml')])
            for name, args in (('ours', AC), ('ours_n0', ['-n', '0'] + AC)):
                rc, out, err = sh([EXE, '-nopdf', '-o', os.path.join(W, name)] + args + ['!(%s)' % ours], cwd=W, timeout=LIMIT)
                if rc != 0:
                    o.write('\t'.join([i, name] + ['NA'] * 7) + '\n'); continue
                m = re.search(r'(\d+) clocks, (\d+) locations, (\d+) transitions', out)
                clocks, locs, trans = m.groups() if m else ('NA',) * 3
                tp.write(os.path.join(W, 'm.tck'), [tp.from_xml('SYS', os.path.join(W, 'sys.xml')), tp.from_xml('NEG', os.path.join(W, name + '.xml'))], events)
                a = [tp.from_xml('SYS', os.path.join(W, 'sys.xml')), tp.from_xml('NEG', os.path.join(W, name + '.xml'))]
                ls = sorted({l for x in a for v in x.locs.values() for l in v[0]})
                labels = ','.join(['div'] + ls)
                row = [i, name, locs, trans, clocks] + list(run_tck(W, labels))
                o.write('\t'.join(map(str, row)) + '\n'); o.flush()
                print('\t'.join(map(str, row)), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
