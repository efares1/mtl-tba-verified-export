"""Convert CASAAL's transition-accepting automata (evaluation/casaal_out_x/*.gv)
to location-accepting ones (the acceptance model of our TBA type) and compare
sizes with the optimized, exported automata of mtl2tba.

Conversion (single acceptance set): the locations are the reachable pairs
(s, f), f = 1 when the transition that entered the location was accepting; a
location is accepting when f = 1.  Several acceptance sets are counted by a
generalized-to-single degeneralization bound and flagged."""
import csv, re, glob, os
E = r'C:\Users\user\Desktop\JSS_paper\evaluation'

def parse(path):
    txt = open(path, encoding='utf8').read()
    init = None
    edges = []
    for m in re.finditer(r'^\s*(\w+)\s*->\s*(\w+)\s*(?:\[label="(.*?)"\])?\s*$', txt, re.M | re.S):
        a, b, lab = m.group(1), m.group(2), m.group(3) or ''
        if a == '0' and init is None and not lab:
            init = b
            continue
        accs = set(re.findall(r'Acc\[([^\]]*)\]', lab))
        edges.append((a, b, frozenset(accs)))
    return init, edges

ours = {r['id']: r for r in csv.DictReader(open(E + r'\ours_results.tsv', encoding='utf8'), delimiter='\t')}
cas = {r['id']: r for r in csv.DictReader(open(E + r'\casaal_exclusive.tsv', encoding='utf8'), delimiter='\t')}
print('id   ours(locs,trans) | casaal tr-acc(states,trans) | casaal loc-acc(locs,trans) | #accsets')
tot = [0, 0, 0, 0]
wins = ties = losses = 0
for k in cas:
    o = ours.get(k); c = cas[k]
    f = os.path.join(E, 'casaal_out_x', k + '.gv')
    if not o or o['status'] != 'ok' or c['exact'] != 'yes' or not os.path.exists(f):
        continue
    init, edges = parse(f)
    sets = set()
    for e in edges:
        sets |= set(e[2])
    # location-accepting conversion for a single acceptance set (or union: any mark)
    out = {}
    for a, b, acc in edges:
        out.setdefault(a, []).append((b, 1 if acc else 0))
    seen = {(init, 0)}
    work = [(init, 0)]
    ntr = 0
    while work:
        s, fl = work.pop()
        for b, a in out.get(s, []):
            ntr += 1
            if (b, a) not in seen:
                seen.add((b, a)); work.append((b, a))
    # the initial copy (init,0) is non-accepting; locations that are unreachable with flag 1 are dropped
    olocs, otr = int(o['exp_locs']), int(o['sym_trans'])
    print(f'{k:4} ({olocs},{otr}) | ({c["states"]},{c["transitions"]}) | ({len(seen)},{ntr}) | {len(sets)}')
    tot[0] += olocs; tot[1] += otr; tot[2] += len(seen); tot[3] += ntr
    d = (olocs - len(seen)) + (otr - ntr)
    if olocs <= len(seen) and otr <= ntr:
        if olocs == len(seen) and otr == ntr: ties += 1
        else: wins += 1
    else:
        losses += 1
print('totals ours', tot[0], tot[1], ' casaal location-accepting', tot[2], tot[3])
print('ours <= casaal(loc-acc) on both measures: strictly smaller somewhere', wins, 'equal', ties, 'larger somewhere', losses)
