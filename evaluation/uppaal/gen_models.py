"""Generate the UPPAAL models of the UPPAAL experiment (run under WSL):

    python3 gen_models.py

For each requirement the property automaton of its NEGATION comes in these variants:
  ours_default   mtl2tba, optimizer on, maximal-delay export (the default)
  ours_n0        mtl2tba -n 0 (no optimization rounds; export still runs)
  ours_allcopy   mtl2tba -all-copy
  casaal_plain   CASAAL's automaton (casaal_out_neg/<id>.gv), acceptance moved to
                 locations by casaal_to_tba.py, written as UPPAAL XML WITHOUT any
                 invariant and without any of our passes (plain converter below)
  casaal_n0      the same automaton through tba_opt -n 0 (our export, no optimization)
  casaal_opt     the same automaton through tba_opt (optimizer + export)
  casaal_allcopy the same automaton through tba_opt -all-copy
and is composed with system models.  Query: E<> P.<universal accepting sink(s)>, which
detects a violation (a bad prefix) of a safety requirement.  Expected verdict: 'ok'
systems -> not satisfied, 'bad' systems -> satisfied.
Positive-form block ("pos"): the requirement itself (not negated) with our three export
variants and the 'ok' system; used to check that UPPAAL reads the default export.
"""
import os, re, subprocess, sys, json, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
EV = os.path.join(HERE, '..')
TOOL = os.path.join(EV, '..', 'tool', '_build', 'default', 'src')
EXE = os.path.join(TOOL, 'mtl2tba.exe')
OPT = os.environ.get('OPT', os.path.expanduser('~/tool_copy/_build/default/src/tba_opt.exe'))
OUT = os.path.join(HERE, 'models')
os.makedirs(OUT, exist_ok=True)

HEAD = ("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE nta PUBLIC '-//Uppaal Team//DTD Flat "
        "System 1.1//EN' 'http://www.it.uu.se/research/group/darts/uppaal/flat-1_2.dtd'>\n<nta>\n")

def sh(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit('failed: %s\n%s%s' % (' '.join(cmd), r.stdout, r.stderr))
    return r.stdout

# ---- system templates (as in evaluation/case_study/make_models.py) -------------------
def edge(src, tgt, sync, guard=None, assign=None):
    s = '    <transition>\n      <source ref="%s"/>\n      <target ref="%s"/>\n' % (src, tgt)
    if guard:
        s += '      <label kind="guard">%s</label>\n' % guard.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    s += '      <label kind="synchronisation">%s</label>\n' % sync
    if assign:
        s += '      <label kind="assignment">%s</label>\n' % assign
    return s + '    </transition>\n'

def loc(i, name, inv=None):
    s = '    <location id="%s" x="0" y="0">\n      <name>%s</name>\n' % (i, name)
    if inv:
        s += '      <label kind="invariant">%s</label>\n' % inv.replace('<', '&lt;')
    return s + '    </location>\n'

def sporadic(k):
    return ('  <template>\n    <name>Sys</name>\n    <declaration>clock y, z;</declaration>\n'
            + loc('s0', 'S') + '    <init ref="s0"/>\n'
            + edge('s0', 's0', 'e!', 'y >= %s && z > 0' % k, 'y = 0, z = 0')
            + edge('s0', 's0', 'other!', 'z > 0', 'z = 0') + '  </template>\n')

def response(d):
    return ('  <template>\n    <name>Sys</name>\n    <declaration>clock y, z;</declaration>\n'
            + loc('s0', 'Idle') + loc('s1', 'Busy', 'y <= %s' % d) + '    <init ref="s0"/>\n'
            + edge('s0', 's1', 'p!', 'z > 0', 'y = 0, z = 0')
            + edge('s0', 's0', 'other!', 'z > 0', 'z = 0')
            + edge('s1', 's1', 'other!', 'z > 0 && y < %s' % d, 'z = 0')
            + edge('s1', 's0', 'q!', 'z > 0 && y >= 1', 'z = 0') + '  </template>\n')

def resp_family(n, bad):
    """template Sys of evaluation/make_resp_system.py (R_n)"""
    with tempfile.TemporaryDirectory() as w:
        f = os.path.join(w, 's.xml')
        sh([sys.executable, os.path.join(EV, 'make_resp_system.py'), str(n), f] + (['bad'] if bad else []))
        x = open(f, encoding='utf8').read()
    t = re.search(r'  <template>.*?</template>\n', x, re.S).group(0)
    # UPPAAL wants every location before <init>
    ini = re.search(r'    <init ref="[^"]+"/>\n', t).group(0)
    t = t.replace(ini, '')
    i = t.index('    <transition>')
    return t[:i] + ini + t[i:]

def free_sys(chans):
    """emits any event at any (strictly later) time; used to explore the property automaton alone"""
    return ('  <template>\n    <name>Sys</name>\n    <declaration>clock z;</declaration>\n'
            + loc('s0', 'S') + '    <init ref="s0"/>\n'
            + ''.join(edge('s0', 's0', c + '!', 'z > 0', 'z = 0') for c in chans) + '  </template>\n')

# ---- property automata -------------------------------------------------------------
def prop_part(xml):
    decl = re.search(r'<declaration>(chan [^<]*)</declaration>', xml).group(1)
    tpl = re.search(r'  <template>\s*<name>Property</name>.*?</template>\n', xml, re.S).group(0)
    return decl, tpl

def plain_from_tba(tba_path, events):
    """CASAAL's automaton (location acceptance, from casaal_to_tba.py) as UPPAAL XML:
    no invariants; a transition with a positive event literal reads that event, one with
    only negative literals reads every event except those (and 'other')."""
    evs = events + ['other']
    nst, init, acc, names = 0, 0, set(), None
    for l in open(tba_path, encoding='utf8'):
        w = l.split()
        if not w: continue
        if w[0] == 'events': names = w[1:]
        elif w[0] == 'states': nst = int(w[1])
        elif w[0] == 'init': init = int(w[1])
        elif w[0] == 'acc': acc = {int(x) for x in w[1:]}
    trs = []
    for l in open(tba_path, encoding='utf8'):
        if l.startswith('t '):
            a, c, d, r = [p.strip() for p in l[2:].split('|')]
            s, t = a.split()
            trs.append((int(s), int(t), c.split(), d.split(), r.split()))
    nclk = 0
    for l in open(tba_path, encoding='utf8'):
        if l.startswith('clocks'): nclk = int(l.split()[1])
    out = ['  <template>', '    <name>Property</name>']
    out.append('    <declaration>clock %s;</declaration>' % ', '.join('x%d' % i for i in range(nclk)) if nclk else '    <declaration></declaration>')
    for i in range(nst):
        out.append('    <location id="id%d" x="0" y="0"><name>%s%d</name></location>' % (i, 'A' if i in acc else 'L', i))
    out.append('    <init ref="id%d"/>' % init)
    for (s, t, lab, gd, rs) in trs:
        pos = [names[int(x[:-1])] for x in lab if x.endswith('+')]
        neg = [names[int(x[:-1])] for x in lab if x.endswith('-')]
        if len(set(pos)) > 1: continue
        evl = [pos[0]] if pos else [e for e in evs if e not in neg]
        if pos and pos[0] in neg: continue
        g = ' &amp;&amp; '.join(re.sub(r'^(\d+)', r'x\1', x).replace('<', '&lt;').replace('>', '&gt;') for x in gd)
        asg = ', '.join('x%s = 0' % r for r in rs)
        for e in evl:
            lines = ['    <transition><source ref="id%d"/><target ref="id%d"/>' % (s, t)]
            if g: lines.append('<label kind="guard">%s</label>' % g)
            lines.append('<label kind="synchronisation">%s?</label>' % e)
            if asg: lines.append('<label kind="assignment">%s</label>' % asg)
            lines.append('</transition>')
            out.append(''.join(lines))
    out.append('  </template>')
    return 'chan %s;' % ', '.join(evs), '\n'.join(out) + '\n'

def sinks(tpl, decl):
    """accepting locations that only loop on themselves, unguarded, on every channel"""
    chans = set(re.findall(r'[A-Za-z_]\w*', decl)) - {'chan'}
    names = dict((m.group(1), m.group(2)) for m in re.finditer(r'<location id="([^"]+)"[^>]*>\s*<name>([^<]+)</name>', tpl))
    res = []
    for lid, nm in names.items():
        if not nm.startswith('A'): continue
        seen, ok = set(), True
        for m in re.finditer(r'<transition>(.*?)</transition>', tpl, re.S):
            body = m.group(1)
            src = re.search(r'<source ref="([^"]+)"', body).group(1)
            if src != lid: continue
            tgt = re.search(r'<target ref="([^"]+)"', body).group(1)
            if tgt != lid or 'kind="guard"' in body: ok = False; break
            seen.add(re.search(r'kind="synchronisation">(\w+)\?', body).group(1))
        if ok and seen >= chans: res.append(nm)
    return res

def write_model(name, decl, prop, system, sysline, query):
    with open(os.path.join(OUT, name + '.xml'), 'w', encoding='utf-8') as f:
        f.write(HEAD + '  <declaration>%s</declaration>\n' % decl + prop + system + sysline + '\n</nta>\n')
    with open(os.path.join(OUT, name + '.q'), 'w', encoding='utf-8') as f:
        f.write(query + '\n')

def diag_count(xml):
    return len(re.findall(r'x\d+\s*-\s*x\d+\s*(?:&lt;|&gt;|==|!=)', xml))

SYSLINE = '  <system>P = Property();\nS = Sys();\nsystem P, S;</system>'

def variants(W, formula, events, gv, neg=True):
    f = ('!(%s)' % formula) if neg else formula
    res = {}
    for tag, args in (('ours_default', []), ('ours_n0', ['-n', '0']), ('ours_allcopy', ['-all-copy'])):
        sh([EXE, '-nopdf'] + args + ['-o', os.path.join(W, tag), f], cwd=W)
        res[tag] = prop_part(open(os.path.join(W, tag + '.xml'), encoding='utf8').read()) + (diag_count(open(os.path.join(W, tag + '.xml'), encoding='utf8').read()),)
    if gv and neg:
        tba = os.path.join(W, 'c.tba')
        sh([sys.executable, os.path.join(EV, 'casaal_to_tba.py'), gv, tba, ','.join(events)])
        d, p = plain_from_tba(tba, events)
        res['casaal_plain'] = (d, p, 0)
        for tag, args in (('casaal_n0', ['-n', '0']), ('casaal_opt', []), ('casaal_allcopy', ['-all-copy'])):
            sh([OPT, '-o', os.path.join(W, tag)] + args + [tba], cwd=W)
            x = open(os.path.join(W, tag + '.xml'), encoding='utf8').read()
            res[tag] = prop_part(x) + (diag_count(x),)
    return res

# ---- cases ---------------------------------------------------------------------------
CASES = []
# case-study systems with the non-hatted bounded response F1 (CASAAL expresses it exactly)
CASES.append(dict(id='F1', formula='[](p -> <>[<=5] q)', events=['p', 'q'], gv=os.path.join(EV, 'casaal_out_neg', 'F1.gv'),
                  systems=[('ok', response(4), 'not satisfied'), ('bad', response(6), 'satisfied')]))
# hatted sporadicity: CASAAL has no exact encoding (formulas.tsv marks it '~'), ours only
CASES.append(dict(id='F3', formula='[](e -> ^[][<=2] !e)', events=['e'], gv=None,
                  systems=[('ok', sporadic(3), 'not satisfied'), ('bad', sporadic(1), 'satisfied')]))
for n in (1, 2, 3, 4):
    f = ' & '.join('[](a%d -> <>[<=5] b%d)' % (i, i) for i in range(1, n + 1))
    ev = sum([['a%d' % i, 'b%d' % i] for i in range(1, n + 1)], [])
    CASES.append(dict(id='R%d' % n, formula=f, events=ev, gv=os.path.join(EV, 'casaal_out_neg', 'R%d.gv' % n),
                      systems=[('ok', resp_family(n, False), 'not satisfied'), ('bad', resp_family(n, True), 'satisfied')]))

manifest = []
for c in CASES:
    W = tempfile.mkdtemp()
    try:
        vs = variants(W, c['formula'], c['events'], c['gv'])
        for vt, (decl, prop, diag) in vs.items():
            sk = sinks(prop, decl)
            for st, sysx, exp in c['systems']:
                nm = '%s_%s_%s' % (c['id'], st, vt)
                q = 'E<> ' + (' || '.join('P.' + s for s in sk) if sk else 'false')
                write_model(nm, decl, prop, sysx, SYSLINE, q)
                manifest.append(dict(name=nm, case=c['id'], system=st, variant=vt, block='neg', expected=exp, sinks=sk, diag=diag))
        # free environment: the whole zone graph of the property automaton (A[] true explores everything)
        for vt, (decl, prop, diag) in vs.items():
            chans = [x for x in re.findall(r'[A-Za-z_]\w*', decl) if x != 'chan']
            nm = '%s_free_%s' % (c['id'], vt)
            write_model(nm, decl, prop, free_sys(chans), SYSLINE, 'A[] true')
            manifest.append(dict(name=nm, case=c['id'], system='free', variant=vt, block='free', expected='satisfied', sinks=[], diag=diag))
        # positive form (the requirement itself) with the three export variants and the ok system
        if c['id'] in ('F1', 'R1', 'R2', 'R3', 'R4'):
            pv = variants(W, c['formula'], c['events'], None, neg=False)
            for vt, (decl, prop, diag) in pv.items():
                accs = sorted(set(re.findall(r'<name>(A\d+)</name>', prop)))
                st, sysx, exp = c['systems'][0]
                nm = '%s_%s_pos_%s' % (c['id'], st, vt)
                q = 'E<> ' + (' || '.join('P.' + s for s in accs) if accs else 'false')
                write_model(nm, decl, prop, sysx, SYSLINE, q)
                manifest.append(dict(name=nm, case=c['id'], system=st, variant=vt, block='pos', expected='(acceptance check)', sinks=accs, diag=diag))
    finally:
        shutil.rmtree(W, ignore_errors=True)

def par_sys(n, bad):
    """n independent request/response components (own clock y_i each, global clock z for strictly
    increasing time) plus a component emitting 'other'; component 1 answers within 6 if bad, else within 2"""
    T = ''
    for i in range(1, n + 1):
        d = 6 if (bad and i == 1) else 2
        T += ('  <template>\n    <name>C%d</name>\n    <declaration>clock y;</declaration>\n' % i
              + loc('i', 'Idle') + loc('w', 'Wait', 'y <= %d' % d) + '    <init ref="i"/>\n'
              + edge('i', 'w', 'a%d!' % i, 'z > 0', 'y = 0, z = 0')
              + edge('w', 'i', 'b%d!' % i, 'z > 0 && y >= 1', 'z = 0') + '  </template>\n')
    T += ('  <template>\n    <name>O</name>\n' + loc('o', 'O') + '    <init ref="o"/>\n'
          + edge('o', 'o', 'other!', 'z > 0', 'z = 0') + '  </template>\n')
    line = ('  <system>P = Property();\n' + ''.join('I%d = C%d();\n' % (i, i) for i in range(1, n + 1))
            + 'Oth = O();\nsystem P, ' + ', '.join('I%d' % i for i in range(1, n + 1)) + ', Oth;</system>')
    return T, line

for n in (1, 2, 3, 4, 5, 6):
    c = dict(id='R%d' % n, formula=' & '.join('[](a%d -> <>[<=5] b%d)' % (i, i) for i in range(1, n + 1)),
             events=sum([['a%d' % i, 'b%d' % i] for i in range(1, n + 1)], []),
             gv=os.path.join(EV, 'casaal_out_neg', 'R%d.gv' % n))
    W = tempfile.mkdtemp()
    try:
        vs = variants(W, c['formula'], c['events'], c['gv'])
        for vt, (decl, prop, diag) in vs.items():
            sk = sinks(prop, decl)
            for st, bad in (('parok', False), ('parbad', True)):
                T, line = par_sys(n, bad)
                nm = '%s_%s_%s' % (c['id'], st, vt)
                q = 'E<> ' + (' || '.join('P.' + s for s in sk) if sk else 'false')
                write_model(nm, decl + ' clock z;', prop, T, line, q)
                manifest.append(dict(name=nm, case=c['id'], system=st, variant=vt, block='par',
                                     expected='satisfied' if bad else 'not satisfied', sinks=sk, diag=diag))
    finally:
        shutil.rmtree(W, ignore_errors=True)

# extra requirements: free-environment exploration only (A[] true), ours and CASAAL variants
EXTRA = ['F2', 'F4', 'F5', 'F7', 'F8', 'F11', 'F12', 'R5', 'R6', 'N1', 'N2', 'N3', 'N4', 'N5']
tsv = [l.rstrip('\n').split('\t') for l in open(os.path.join(EV, 'formulas.tsv'), encoding='utf8') if l.strip() and not l.startswith('#')]
for rec in tsv:
    if rec[0] not in EXTRA: continue
    i, ours = rec[0], rec[2]
    events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
    gv = os.path.join(EV, 'casaal_out_neg', i + '.gv')
    W = tempfile.mkdtemp()
    try:
        try:
            vs = variants(W, ours, events, gv if os.path.exists(gv) else None)
        except SystemExit as e:
            print(i, 'skipped:', str(e)[:200]); continue
        for vt, (decl, prop, diag) in vs.items():
            chans = [x for x in re.findall(r'[A-Za-z_]\w*', decl) if x != 'chan']
            nm = '%s_free_%s' % (i, vt)
            write_model(nm, decl, prop, free_sys(chans), SYSLINE, 'A[] true')
            manifest.append(dict(name=nm, case=i, system='free', variant=vt, block='free', expected='satisfied', sinks=[], diag=diag))
    finally:
        shutil.rmtree(W, ignore_errors=True)
# case-study spor with hatted formula: also its positive form is not needed
json.dump(manifest, open(os.path.join(HERE, 'manifest.json'), 'w'), indent=1)
print(len(manifest), 'models')
