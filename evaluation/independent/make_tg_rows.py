"""Rows of the train_gate table from pilot_results.tsv and pilot_n3_d25.tsv."""
import csv
rows = []
for f in ('pilot_results.tsv', 'pilot_n3_d25.tsv'):
    for l in open(f, encoding='utf-8'):
        c = l.rstrip('\n').split('\t')
        if len(c) >= 9 and c[0].isdigit():
            rows.append(c + ['NA'] * (13 - len(c)))
names = {'ours_n0': 'no optimization', 'ours': 'default optimizer', 'ours_checked': 'checked pruning and reuse', 'casaal': 'CASAAL, converted'}
order = ['ours_n0', 'ours', 'ours_checked', 'casaal']
seen = {}
for c in rows:
    seen[(int(c[0]), int(c[2]), c[3])] = c
out = []
for N in (2, 3, 4):
    for D in (25, 24):
        for v in order:
            c = seen.get((N, D, v))
            if not c:
                continue
            verdict = c[8]
            if verdict.startswith('err') and 'bad_alloc' in verdict:
                verdict = 'memory'
            stored = c[9] if c[9] != 'NA' else '--'
            search = ('%.2f' % float(c[10])) if c[10] != 'NA' else '--'
            peak = c[12] if c[12] != 'NA' else '--'
            fmt = lambda x: f'{int(x):,}'.replace(',', r'\,') if x.isdigit() else x
            gen = '--' if v == 'casaal' else c[7]
            out.append(f'{N} & {D} & {names[v]} & {fmt(c[4])} & {fmt(c[5])} & {c[6]} & {gen} & {verdict} & {fmt(stored)} & {search} & {peak}\\\\')
        out.append('\\addlinespace')
open('tg_rows.tex', 'w', newline='').write('\n'.join(out[:-1]) + '\n')
print('\n'.join(out))
