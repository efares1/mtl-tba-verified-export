"""Table of the zone-graph structure (zone_probe.tsv, zone_cov.tsv) -> zone_table.tex.  The last row has no row end."""
import csv, os
HERE = os.path.dirname(os.path.abspath(__file__))
EOL = chr(92) * 2


def fmt(v):
    return '--' if v in ('NA', '', None) else '{:,}'.format(int(v)).replace(',', '{,}')


rows = {(r['id'], r['arm']): r for r in csv.DictReader(open(os.path.join(HERE, 'zone_probe.tsv'), encoding='utf8'), delimiter='\t')}
cov = {(r['id'], r['arm']): r for r in csv.DictReader(open(os.path.join(HERE, 'zone_cov.tsv'), encoding='utf8'), delimiter='\t')}
L = []
for i in ['R1', 'R2', 'R3', 'R4']:
    cells = [i]
    for arm in ('ours', 'casaal_exp'):
        r = rows.get((i, arm))
        c = cov.get((i, arm), {}).get('covreach_stored', 'NA')
        if r:
            cells += [fmt(r['nodes']), fmt(r['vectors']), fmt(r['max_nodes_per_vector']), fmt(c)]
        else:
            cells += ['--', '--', '--', fmt(c)]
    L.append(' & '.join(cells) + ' ' + EOL)
open(os.path.join(HERE, 'zone_table.tex'), 'w', encoding='utf8').write(chr(10).join(L)[:-2].rstrip() + chr(10))
print(open(os.path.join(HERE, 'zone_table.tex')).read())
