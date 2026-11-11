"""Isolating experiment: remove the dominated nondeterministic edges of CASAAL's positive automaton and see whether
the zone graph collapses.

The positive automaton of a bounded response (CASAAL, location acceptance, exported by our tool with -n 0 -all-copy) is a
safety automaton whose guards and invariants are conjunctions of upper bounds x<=c / x<c.  For such automata a
simulation can be computed syntactically.  Let L(q) be the clocks that may be read from q before being reset.  Say that
q1 covers q2 (q1 >= q2) when, for every valuation w2 and every w1 with w1 <= w2 on L(q1), every run of (q2, w2) can be
followed by (q1, w1).  The greatest relation with
  (i)  every bound of inv(q1) is at least the bound of inv(q2) on the same clock (and q2 bounds that clock),
  (ii) every edge q2 -a,g2,R2-> q2' is matched by an edge q1 -a,g1,R1-> q1' with g1 >= g2 (as in (i)),
       no clock of L(q1') is in R2 minus R1, and q1' >= q2'
is such a relation.  An edge e2 is dominated if another edge e1 of the same source and event matches it in the sense of
(ii).  Dominated edges are removed one at a time, ties (mutual domination) broken by edge index, and the relation is
recomputed after each removal, so that every removal is justified in the automaton it is applied to.
This argument is ours and is not mechanized; the language is therefore also compared with the independent MTL judge
of evaluation/differential on random lasso words (the pruned and the original automaton, all locations accepting).

Usage (WSL): python3 prune_casaal.py ID [WORDS]      (ID = R2, R3, ...; writes prune_<ID>.xml, prints a summary row)"""
import os, re, sys, random, subprocess, tempfile, shutil, itertools
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'differential'))
import tck_product as tp
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OPT = os.environ.get('OPT', os.path.expanduser('~/tool_copy/_build/default/src/tba_opt.exe'))
TCK = os.path.expanduser('~/local/bin/tck-liveness')
TREACH = os.path.expanduser('~/local/bin/tck-reach')
ID = sys.argv[1]
NWORDS = int(sys.argv[2]) if len(sys.argv) > 2 else 3000

ATOM = re.compile(r'^\s*([A-Za-z_]\w*)\s*(<=|<)\s*(\d+)\s*$')


def parse_ub(text):
    """conjunction of upper bounds -> {clock: (bound, strict)} (the tightest if repeated); None if not of this form"""
    d = {}
    for a in [x for x in (text or '').split('&&') if x.strip()]:
        m = ATOM.match(a)
        if not m:
            return None
        c, op, b = m.group(1), m.group(2), int(m.group(3))
        k = (b, op == '<')
        if c not in d or tight(k) < tight(d[c]):
            d[c] = k
    return d


def tight(k):           # smaller = more restrictive: x<5 is tighter than x<=5
    return (k[0], 0 if k[1] else 1)


def weaker_or_eq(g1, g2):
    """every valuation satisfying g2 satisfies g1 (g1, g2 conjunctions of upper bounds)"""
    return all(c in g2 and tight(g2[c]) <= tight(k1) for c, k1 in g1.items())


class Aut:
    def __init__(self, path):
        self.tree = ET.parse(path)
        t = [t for t in self.tree.getroot().findall('template') if t.findtext('name') == 'Property'][0]
        self.t = t
        self.inv, self.name = {}, {}
        for l in t.findall('location'):
            lid = l.get('id')
            self.name[lid] = l.findtext('name')
            self.inv[lid] = parse_ub(l.findtext("label[@kind='invariant']"))
        self.init = t.find('init').get('ref')
        self.edges = []     # (element, src, ev, guard, resets, tgt)
        for tr in t.findall('transition'):
            g = parse_ub(tr.findtext("label[@kind='guard']"))
            sy = tr.findtext("label[@kind='synchronisation']").rstrip('?')
            asg = tr.findtext("label[@kind='assignment']") or ''
            rs = frozenset(re.findall(r'(\w+)\s*=\s*0', asg))
            self.edges.append((tr, tr.find('source').get('ref'), sy, g, rs, tr.find('target').get('ref')))
        if any(v is None for v in self.inv.values()) or any(e[3] is None for e in self.edges):
            raise SystemExit('not an upper-bound automaton')

    def live(self, edges):
        L = {l: set(self.inv[l]) for l in self.inv}
        ch = True
        while ch:
            ch = False
            for (_, s, ev, g, rs, t) in edges:
                new = set(g) | (L[t] - rs)
                if not new <= L[s]:
                    L[s] |= new
                    ch = True
        return L

    def simulation(self, edges):
        L = self.live(edges)
        locs = list(self.inv)
        S = {(a, b) for a in locs for b in locs if weaker_or_eq(self.inv[a], self.inv[b])}
        out = {}
        for e in edges:
            out.setdefault((e[1], e[2]), []).append(e)
        evs = {e[2] for e in edges}
        ch = True
        while ch:
            ch = False
            for (q1, q2) in list(S):
                ok = True
                for ev in evs:
                    for e2 in out.get((q2, ev), ()):
                        if not any(weaker_or_eq(e1[3], e2[3]) and not (L[e1[5]] & (e2[4] - e1[4])) and (e1[5], e2[5]) in S
                                   for e1 in out.get((q1, ev), ())):
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    S.discard((q1, q2))
                    ch = True
        return S, L, out

    def prune(self):
        edges = list(self.edges)
        removed = 0
        changed = True
        while changed:
            changed = False
            S, L, out = self.simulation(edges)
            for e2 in edges:
                for e1 in out.get((e2[1], e2[2]), ()):
                    if e1 is e2:
                        continue
                    if weaker_or_eq(e1[3], e2[3]) and not (L[e1[5]] & (e2[4] - e1[4])) and (e1[5], e2[5]) in S:
                        # e1 dominates e2; if e2 also dominates e1 (equivalent), keep the earlier one
                        back = weaker_or_eq(e2[3], e1[3]) and not (L[e2[5]] & (e1[4] - e2[4])) and (e2[5], e1[5]) in S
                        if back and self.edges.index(e1) > self.edges.index(e2):
                            continue
                        edges.remove(e2)
                        removed += 1
                        changed = True
                        break
                if changed:
                    break
        keep = {id(e[0]) for e in edges}
        for tr in list(self.t.findall('transition')):
            if id(tr) not in keep:
                self.t.remove(tr)
        return edges, removed

    def write(self, path):
        self.tree.write(path, encoding='utf-8', xml_declaration=True)


def sh(cmd, cwd=None, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def stored(W, events, xml, label):
    first = tp.from_xml('SYS', os.path.join(W, 'sys.xml'))
    a = tp.from_xml('NEG', xml)
    autos, labels = [first, a], ['div']
    for x in autos:
        ls = sorted({l for v in x.locs.values() for l in v[0]})
        if x.state_based and not ls:
            ls = ['acc' + x.name]
            x.locs['unreach'] = (ls, None, False)
        labels += ls
    tp.write(os.path.join(W, 'm.tck'), autos, events)
    lab = ','.join(labels)
    rc, out, err = sh(['timeout', '-s', 'KILL', '300', TCK, '-a', 'couvscc', '-l', lab, os.path.join(W, 'm.tck')], timeout=330)
    m = re.search(r'^STORED_STATES (\d+)', out, re.M)
    cyc = re.search(r'^CYCLE (true|false)', out, re.M)
    rc, out2, _ = sh(['timeout', '-s', 'KILL', '300', TREACH, '-a', 'covreach', os.path.join(W, 'm.tck')], timeout=330)
    m2 = re.search(r'^STORED_STATES (\d+)', out2, re.M)
    return (m.group(1) if m else 'NA', cyc.group(1) if cyc else 'NA', m2.group(1) if m2 else 'NA')


def words_check(f, xml_a, xml_b, n):
    """compare two automata (all locations accepting) and the MTL judge on random lasso words"""
    from dlib import OursAut, parse_mtl, judge, mtl_props
    from run_diff_words import constants, random_word
    A, B = OursAut(xml_a), OursAut(xml_b)
    A.acc, B.acc = set(A.locs), set(B.locs)
    F = parse_mtl(f)
    props = sorted(mtl_props(F))
    consts = constants(F)
    rng = random.Random(1)
    dis_ab = dis_bj = pos = 0
    for _ in range(n):
        w = random_word(rng, props, consts)
        a, b, j = A.accepts(w), B.accepts(w), judge(F, w)
        pos += j
        dis_ab += a != b
        dis_bj += b != j
    return n, pos, dis_ab, dis_bj


def main():
    recs = {l.split('\t')[0]: l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8')
            if l.strip() and not l.startswith('#')}
    f = recs[ID][2]
    events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)) - {'true', 'false'})
    W = tempfile.mkdtemp()
    try:
        tba = os.path.join(W, 'c.tba')
        sh([sys.executable, os.path.join(HERE, 'casaal_to_tba.py'), os.path.join(HERE, 'casaal_out', ID + '.gv'), tba, ','.join(events)])
        sh([OPT, '-o', os.path.join(W, 'orig'), '-n', '0', '-all-copy', tba])
        n = re.match(r'R(\d+)$', ID).group(1)
        sh([sys.executable, os.path.join(HERE, 'make_resp_system.py'), n, os.path.join(W, 'sys0.xml'), 'badall'])
        sh([sys.executable, os.path.join(HERE, 'tck_normalize_system.py'), os.path.join(W, 'sys0.xml'), os.path.join(W, 'sys.xml')])
        a = Aut(os.path.join(W, 'orig.xml'))
        n0 = len(a.edges)
        keep, removed = a.prune()
        outp = os.path.join(HERE, 'prune_%s.xml' % ID)
        a.write(outp)
        nd = lambda es: sum(1 for k, v in __import__('collections').Counter((e[1], e[2]) for e in es).items() if v > 1)
        print('%s edges %d -> %d (removed %d); (loc,event) pairs with >=2 edges: %d -> %d'
              % (ID, n0, len(keep), removed, nd(Aut(os.path.join(W, 'orig.xml')).edges), nd(keep)), flush=True)
        for nm, p in (('orig', os.path.join(W, 'orig.xml')), ('pruned', outp)):
            if nm == 'orig' and os.environ.get('SKIP_ORIG'):
                continue
            print(ID, nm, 'couvscc stored / cycle / covreach stored:', *stored(W, events, p, nm), flush=True)
        if NWORDS:
            print(ID, 'words, positive, pruned!=orig, pruned!=judge:', *words_check(f, os.path.join(W, 'orig.xml'), outp, NWORDS), flush=True)
    finally:
        shutil.rmtree(W, ignore_errors=True)


main()
