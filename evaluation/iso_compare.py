"""Step 2 of the isomorphism check against CASAAL (needs networkx).
Reads isomorphism/dots/<id>_{ours,imp,impopt}.dot (iso_generate.py) and decides
whether the exported automata are isomorphic up to renaming of locations, of
clocks and of transitions: same event sets on the transitions, same guards,
resets and invariants (as written, so a guard that is equivalent but
written differently counts as a difference), same initial and accepting
locations.  Pairs:
  ours ~ impopt   our automaton of the negated requirement against CASAAL's,
                  imported and optimized by the verified optimizer
  imp  ~ impopt   the import is a fixed point of the optimizer (up to isomorphism)
  ours ~ imp      our automaton against CASAAL's import without optimization
Writes isomorphism/iso_results.tsv.
"""
import glob, os, re, sys
import networkx as nx
from networkx.algorithms.isomorphism import DiGraphMatcher

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, 'isomorphism', 'dots')
ATOM = re.compile(r'(x\d+)(?:\s*-\s*(x\d+))?\s*(<=|<|>=|>|==)\s*(\d+(?:\.\d+)?)$')


def atoms(text):
    out = []
    for a in re.split(r'\s*&&\s*', text.strip()):
        if not a:
            continue
        m = ATOM.match(a.strip())
        if not m:
            raise ValueError('atom %r' % a)
        out.append(m.groups())
    return out


def parse(path):
    s = open(path, encoding='utf8').read()
    init = re.search(r'init -> (L\d+);', s).group(1)
    locs = {}
    for m in re.finditer(r'\n\s*(L\d+) \[shape=(\w+), label="([^"]*)"\]', s):
        name, shape, lab = m.groups()
        parts = lab.split('\\n')
        locs[name] = (shape == 'doublecircle', atoms(parts[1]) if len(parts) > 1 else [])
    edges = []
    for m in re.finditer(r'\n\s*(L\d+) -> (L\d+) \[label="([^"]*)"\]', s):
        a, b, lab = m.groups()
        alts, resets = [], []
        for line in lab.split('\\n'):
            if ':=' in line:
                resets = re.findall(r'x\d+', line.split(':=')[0])
            elif ':' in line:
                g, ev = line.split(':', 1)
                alts.append((atoms(g), ev.strip()))
            else:
                alts.append(([], line.strip()))
        for guard, ev in alts:
            edges.append((a, b, ev, guard, resets))
    return init, locs, edges


def graph(path, alphabet):
    init, locs, edges = parse(path)
    G = nx.DiGraph()
    for l, (acc, inv) in locs.items():
        G.add_node(l, k=('L', acc, l == init))
    clocks = set()

    def link(u, v, d):
        if G.has_edge(u, v):
            G[u][v]['k'] = G[u][v]['k'] | {d}
        else:
            G.add_edge(u, v, k=frozenset([d]))

    for l, (acc, inv) in locs.items():
        for x, y, op, c in inv:
            clocks |= {x} | ({y} if y else set())
            link(l, 'c' + x, ('i+' if y is None else 'id+', op, c))
            if y:
                link(l, 'c' + y, ('id-', op, c))
    for n, (a, b, ev, guard, resets) in enumerate(edges):
        names = alphabet if ev == 'any' else set(ev.split('|'))
        e = 'e%d' % n
        G.add_node(e, k=('E', frozenset(names)))
        link(a, e, ('src',))
        link(e, b, ('dst',))
        for x, y, op, c in guard:
            clocks |= {x} | ({y} if y else set())
            link(e, 'c' + x, ('g' if y is None else 'gd+', op, c))
            if y:
                link(e, 'c' + y, ('gd-', op, c))
        for x in resets:
            clocks.add(x)
            link(e, 'c' + x, ('r',))
    for x in clocks:
        G.add_node('c' + x, k=('C',))
    return G, len(locs), len(edges), len(clocks)


def alphabet_of(paths):
    names = set()
    for p in paths:
        for e in parse(p)[2]:
            names |= set(e[2].split('|'))
    names.discard('any')
    return names | {'other'}


def iso(g1, g2):
    if (g1.number_of_nodes(), g1.number_of_edges()) != (g2.number_of_nodes(), g2.number_of_edges()):
        return False
    gm = DiGraphMatcher(g1, g2, node_match=lambda a, b: a['k'] == b['k'],
                      edge_match=lambda a, b: a['k'] == b['k'])
    return gm.is_isomorphic()


ids = sorted({os.path.basename(p).rsplit('_', 1)[0] for p in glob.glob(os.path.join(D, '*_ours.dot'))},
             key=lambda s: (s[0], int(re.sub(r'\D', '', s) or 0), s))
rows = []
for i in ids:
    f = {k: os.path.join(D, '%s_%s.dot' % (i, k)) for k in ('ours', 'imp', 'impopt')}
    if not all(os.path.exists(p) for p in f.values()):
        continue
    alpha = alphabet_of(f.values())
    try:
        G = {k: graph(p, alpha) for k, p in f.items()}
    except ValueError as e:
        rows.append([i, 'parse error: %s' % e] + [''] * 7)
        continue
    sz = lambda k: '%d/%d/%d' % G[k][1:]
    r = lambda a, b: 'yes' if iso(G[a][0], G[b][0]) else 'no'
    rows.append([i, sz('ours'), sz('imp'), sz('impopt'), r('ours', 'impopt'), r('imp', 'impopt'), r('ours', 'imp')])
hdr = ['id', 'ours L/E/C', 'import L/E/C', 'import_opt L/E/C', 'ours~import_opt', 'import~import_opt', 'ours~import']
with open(os.path.join(HERE, 'isomorphism', 'iso_results.tsv'), 'w', encoding='utf8') as o:
    o.write('\t'.join(hdr) + '\n')
    for r_ in rows:
        o.write('\t'.join(r_) + '\n')
print('\t'.join(hdr))
for r_ in rows:
    print('\t'.join(r_))
