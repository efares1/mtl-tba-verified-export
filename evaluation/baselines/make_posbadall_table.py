"""Tables of the positive-form workload that exercises all n responses (workload posbadall) and of the
structure of the two positive automata.  Reads baselines_posbadall_allcopy.tsv and ../struct_probe.tsv;
writes baseline_posbadall_table.tex and ../struct_table.tex.  A row end at the end of an \\input file
makes the following \\bottomrule misplaced, so the last row has no row end and the including file
adds it."""
import csv, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))
EOL = chr(92) * 2


def fmt(v):
    if v in ('NA', '', None):
        return '--'
    return '{:,}'.format(int(float(v))).replace(',', '{,}')


rows = list(csv.DictReader(open(os.path.join(HERE, 'baselines_posbadall_allcopy.tsv'), encoding='utf8'), delimiter='\t'))
by = collections.defaultdict(dict)
for r in rows:
    by[r['id']][r['arm']] = r
L = []
for i in ['R1', 'R2', 'R3', 'R4', 'R5']:
    a = by[i]
    g = lambda arm: a[arm]['stored'] if arm in a and a[arm]['verdict'] in ('empty', 'nonempty') else 'NA'
    ours, ce = g('ours'), g('casaal_exp')
    ratio = '--'
    if ours != 'NA' and ce != 'NA':
        ratio = '%.1f' % (int(ce) / int(ours)) if int(ce) / int(ours) < 10 else fmt(round(int(ce) / int(ours)))
    L.append(' & '.join([i, fmt(ours), fmt(g('ours_n0')), fmt(g('ours_noinv')), fmt(g('casaal')), fmt(ce), ratio]) + ' ' + EOL)
open(os.path.join(HERE, 'baseline_posbadall_table.tex'), 'w', encoding='utf8').write(
    '\n'.join(L)[:-2].rstrip() + '\n')

srows = list(csv.DictReader(open(os.path.join(HERE, '..', 'struct_probe.tsv'), encoding='utf8'), delimiter='\t'))
s = collections.defaultdict(dict)
for r in srows:
    s[r['id']][r['arm']] = r
L = []
for i in ['R2', 'R3', 'R4', 'R5']:
    o, c = s[i]['ours_pos'], s[i]['casaal_pos']
    pairs = int(o['distinct_(src,event)'])
    L.append(' & '.join([i, o['locs'], o['clocks'], fmt(o['edges']), fmt(c['edges']),
                         '%.1f' % (int(o['edges']) / pairs), '%.1f' % (int(c['edges']) / pairs)]) + ' ' + EOL)
open(os.path.join(HERE, '..', 'struct_table.tex'), 'w', encoding='utf8').write('\n'.join(L)[:-2].rstrip() + '\n')
print(open(os.path.join(HERE, 'baseline_posbadall_table.tex')).read())
print(open(os.path.join(HERE, '..', 'struct_table.tex')).read())

# compact table for the article: ours, CASAAL through our export, ratio, per added response
L = []
EOL2 = chr(92) * 2
for i in ['R1', 'R2', 'R3', 'R4', 'R5']:
    a = by[i]
    ok = lambda arm: arm in a and a[arm]['verdict'] in ('empty', 'nonempty')
    ours = a['ours']['stored'] if ok('ours') else 'NA'
    ce = a['casaal_exp']['stored'] if ok('casaal_exp') else 'NA'
    ratio = '--'
    if ours != 'NA' and ce != 'NA':
        q = int(ce) / int(ours)
        ratio = '%.1f' % q if q < 10 else fmt(round(q))
    L.append(' & '.join([i, fmt(ours), fmt(ce), ratio]) + ' ' + EOL2)
open(os.path.join(HERE, 'posbadall_main_table.tex'), 'w', encoding='utf8').write(
    chr(10).join(L)[:-2].rstrip() + chr(10))
print(open(os.path.join(HERE, 'posbadall_main_table.tex')).read())
