import csv, sys
E = r'C:\Users\user\Desktop\JSS_paper\evaluation'
ours = {r['id']: r for r in csv.DictReader(open(E + r'\ours_results.tsv', encoding='utf8'), delimiter='\t')}
cas = {r['id']: r for r in csv.DictReader(open(E + r'\casaal_exclusive.tsv', encoding='utf8'), delimiter='\t')}
rows = []
for k, c in cas.items():
    o = ours.get(k)
    if not o or o['status'] != 'ok' or c['exact'] != 'yes':
        continue
    rows.append((k, int(o['exp_locs']), int(o['sym_trans']), int(o['exp_clocks']),
                 int(c['states']), int(c['transitions']), int(c['clocks'])))
print(len(rows), 'configurations')
def cmp(i, j, name):
    w = sum(1 for r in rows if r[i] < r[j]); t = sum(1 for r in rows if r[i] == r[j]); l = sum(1 for r in rows if r[i] > r[j])
    print(f'{name}: ours smaller {w}, equal {t}, ours larger {l}; totals ours {sum(r[i] for r in rows)} vs CASAAL {sum(r[j] for r in rows)}')
cmp(1, 4, 'locations')
cmp(2, 5, 'symbolic transitions')
cmp(3, 6, 'clocks')
print('losing rows (id, ours locs/trans/clocks, casaal locs/trans/clocks):')
for r in rows:
    if r[1] > r[4] or r[2] > r[5] or r[3] > r[6]:
        print(' ', r)
print('winning rows:')
for r in rows:
    if r[1] < r[4] or r[2] < r[5] or r[3] < r[6]:
        print(' ', r)
