"""Where does the overlap in CASAAL's positive-form automata (R2..R5) come from?

Reads CASAAL's own DOT output (evaluation/casaal_out/Rn.gv), without the importer's acceptance handling, and reports:
  - printed locations and printed edges, and the number of acceptance marks printed (0 for the bounded-response family,
    so the importer neither splits a location nor drops an edge: it only reads the labels);
  - cubes: the disjuncts of the printed labels (what the importer turns into one transition each);
  - letter-level tuples (source, target, letter, guard atoms, resets) that the cubes denote, with events mutually
    exclusive, and how many of them are duplicates of a tuple of another cube of the same printed edge.
A duplicate here is visible in the DOT file itself: the redundancy is in the printed labels, not created by the importer.

Usage: python3 casaal_label_redundancy.py OUT.tsv"""
import os, re, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'baselines', 'casaal_to_tba_fixed.py'), encoding='utf8').read()
src = src.replace('\nmain()', '\n')
ns = {}
exec(compile(src, 'casaal_to_tba_fixed', 'exec'), ns)
parse_label = ns['parse_label']

rows = []
for n in (2, 3, 4, 5):
    txt = open(os.path.join(HERE, 'casaal_out', 'R%d.gv' % n), encoding='utf8').read()
    marks = len(re.findall(r'Acc\[', txt))
    locs = len(re.findall(r'^\s*\d+\s*\[label="(?:[^"\\]|\\.)*"\]', txt, re.M)) - 0
    edges = []
    for m in re.finditer(r'^\s*(\w+)\s*->\s*(\w+)\s*\[label="(.*?)"\]\s*$', txt, re.M):
        edges.append((m.group(1), m.group(2), m.group(3).replace('\\n', ' ').replace('\\"', '"').strip()))
    evset = set()
    cubes = []
    for (a, b, body) in edges:
        for cube in parse_label(body):
            cubes.append((a, b, cube))
            for k, x, p in cube:
                if k == 'ev':
                    evset.add(x)
    letters = sorted(evset) + ['other']
    tuples_all = 0
    seen = collections.Counter()
    dup_in_edge = 0
    per_edge = collections.defaultdict(list)
    for (a, b, cube) in cubes:
        pos = [x for k, x, p in cube if k == 'ev' and p]
        neg = [x for k, x, p in cube if k == 'ev' and not p]
        if len(set(pos)) > 1:
            ls = []
        elif pos:
            ls = [] if pos[0] in neg else [pos[0]]
        else:
            ls = [l for l in letters if l not in neg]
        g = tuple(sorted(x for k, x, p in cube if k == 'guard'))
        r = tuple(sorted(x for k, x, p in cube if k == 'reset' and p))
        per_edge[(a, b)].append({(l, g, r) for l in ls})
    for key, sets in per_edge.items():
        allset = collections.Counter()
        for s in sets:
            for t in s:
                allset[t] += 1
        tuples_all += sum(allset.values())
        dup_in_edge += sum(c - 1 for c in allset.values())
    # cubes entirely covered by the other cubes of the same printed edge
    covered = 0
    for key, sets in per_edge.items():
        for i, s in enumerate(sets):
            rest = set().union(*[t for j, t in enumerate(sets) if j != i]) if len(sets) > 1 else set()
            if s and s <= rest:
                covered += 1
    rows.append((n, locs, len(edges), marks, len(cubes), tuples_all, tuples_all - dup_in_edge, covered))

with open(sys.argv[1], 'w', encoding='utf8') as o:
    o.write('R\tprinted_locations\tprinted_edges\tacceptance_marks\tcubes\tletter_tuples\tdistinct_letter_tuples\tcubes_covered_by_siblings\n')
    for r in rows:
        o.write('\t'.join(str(x) for x in r) + '\n')
print(open(sys.argv[1]).read())
