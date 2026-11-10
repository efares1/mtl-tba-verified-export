"""System-with-clocks experiment.  For the patterns whose negated automaton loses a clock in
optimization (F2, F3b), compose a system that has its own clocks with the negation produced by
three variants (ours, ours -n 0, CASAAL) and run tck-liveness (couvscc).  A correct system
gives an empty product (full exploration: stored states are comparable); a faulty system gives a
non-empty one (verdict check only).
Usage (WSL): python3 sys_clock_test.py [LIMIT_SECONDS]   Writes sys_clock_test.tsv."""
import os, re, subprocess, sys, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
TCK = os.path.expanduser('~/local/bin/tck-liveness')
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300

def sysxml(locs, edges):
    """locs: [(id, name, invariant or None)], edges: [(src, tgt, sync, guard or None, assign or None)]"""
    s = '<nta><template><name>Property</name><declaration>clock x0, x1;</declaration>\n'
    for i, n, inv in locs:
        s += '<location id="%s"><name>%s</name>' % (i, n)
        if inv:
            s += '<label kind="invariant">%s</label>' % inv
        s += '</location>\n'
    s += '<init ref="%s"/>\n' % locs[0][0]
    for a, b, sy, g, asg in edges:
        s += '<transition><source ref="%s"/><target ref="%s"/>' % (a, b)
        if g:
            s += '<label kind="guard">%s</label>' % g
        s += '<label kind="synchronisation">%s?</label>' % sy
        if asg:
            s += '<label kind="assignment">%s</label>' % asg
        s += '</transition>\n'
    return s + '</template></nta>\n'

LT = '&lt;'; GE = '&gt;='
pulse = lambda loc: (loc, loc, 'other', 'x1 %s 1' % GE, 'x1 = 0')   # environment pulse, clock x1
SYSTEMS = {
  # F2: after p, only q during 3 time units
  ('F2', 'ok'):  ('p,q', sysxml([('i', 'Idle', None), ('b', 'Busy', 'x0 %s= 3' % LT)],
        [pulse('i'), ('i', 'b', 'p', None, 'x0 = 0'), ('b', 'b', 'q', 'x0 %s 3' % LT, None),
         ('b', 'i', 'q', 'x0 %s 3' % GE, None)])),
  ('F2', 'bad'): ('p,q', sysxml([('i', 'Idle', None), ('b', 'Busy', 'x0 %s= 3' % LT)],
        [pulse('i'), ('i', 'b', 'p', None, 'x0 = 0'), ('b', 'b', 'q', 'x0 %s 3' % LT, None),
         ('b', 'i', 'q', 'x0 %s 3' % GE, None), ('b', 'i', 'other', 'x0 %s 2' % GE, None)])),
  # F3b: e at least 3 apart
  ('F3b', 'ok'):  ('e', sysxml([('i', 'Idle', None), ('w', 'Wait', None)],
        [pulse('i'), ('i', 'w', 'e', None, 'x0 = 0'), pulse('w'), ('w', 'w', 'e', 'x0 %s 3' % GE, 'x0 = 0')])),
  ('F3b', 'bad'): ('e', sysxml([('i', 'Idle', None), ('w', 'Wait', None)],
        [pulse('i'), ('i', 'w', 'e', None, 'x0 = 0'), pulse('w'), ('w', 'w', 'e', 'x0 %s 1' % GE, 'x0 = 0')])),
}

def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'

forms = {}
for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    rec = l.rstrip('\n').split('\t')
    if len(rec) >= 4 and not l.startswith('#'):
        forms[rec[0]] = rec[2]

with open(os.path.join(HERE, 'sys_clock_test.tsv'), 'w') as o:
    o.write('id\tsystem\tvariant\tverdict\tstored\tvisited\tseconds\n')
    for (i, kind), (events, xml) in SYSTEMS.items():
        W = tempfile.mkdtemp()
        try:
            open(os.path.join(W, 'sys.xml'), 'w').write(xml)
            sh([EXE, '-nopdf', '-o', 'neg_opt', '!(%s)' % forms[i]], cwd=W)
            sh([EXE, '-nopdf', '-n', '0', '-o', 'neg_n0', '!(%s)' % forms[i]], cwd=W)
            variants = [('ours', 'NEG:' + os.path.join(W, 'neg_opt.xml')),
                        ('ours_n0', 'NEG:' + os.path.join(W, 'neg_n0.xml')),
                        ('casaal', 'NEG:' + os.path.join(HERE, 'casaal_out_neg', i + '.gv'))]
            for var, neg in variants:
                rc, lab, err = sh([sys.executable, os.path.join(HERE, 'tck_product.py'),
                                   os.path.join(W, 'm.tck'), events, neg, 'SYS:' + os.path.join(W, 'sys.xml')])
                if rc != 0:
                    row = [i, kind, var, 'convert-error', 'NA', 'NA', 'NA']
                else:
                    rc, out, err = sh([TCK, '-a', 'couvscc', '-l', lab.strip(), os.path.join(W, 'm.tck')], timeout=LIMIT)
                    v = re.search(r'^CYCLE (true|false)', out, re.M)
                    verdict = {'true': 'nonempty', 'false': 'empty'}[v.group(1)] if v else 'timeout'
                    g = lambda k: (re.search(r'^%s (\S+)' % k, out, re.M) or [None, 'NA'])[1]
                    row = [i, kind, var, verdict, g('STORED_STATES'), g('VISITED_STATES'), g('RUNNING_TIME_SECONDS')]
                o.write('\t'.join(row) + '\n'); o.flush(); print('\t'.join(row), flush=True)
        finally:
            shutil.rmtree(W, ignore_errors=True)
