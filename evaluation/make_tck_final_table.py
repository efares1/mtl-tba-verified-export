"""Final TChecker table: combines
  policy_refac.log, policy_refac3.log  (reference system exported with -all-copy, diagonal-free),
  tck_cost_vs_casaal.tsv               (N1-N3, whose reference has no diagonal guards).
Writes tck_final.tsv and casaal_tck_table.tex (overwrites the table of make_casaal_tables.py)."""
import csv, os, re
D = os.path.dirname(os.path.abspath(__file__))
BS = chr(92)
res = {}
def add(i, v, verd, st, sec): res.setdefault(i, {})[v] = (verd, st, sec)
for fn in ('policy_refac.log', 'policy_refac3.log'):
    for l in open(os.path.join(D, fn), encoding='utf8'):
        f = l.rstrip('\n').split('\t')
        if len(f) >= 8: add(f[0], f[1], f[5], f[6], f[7])
for r in csv.DictReader(open(os.path.join(D, 'tck_cost_vs_casaal.tsv'), encoding='utf8'), delimiter='\t'):
    if r['id'] in ('N1', 'N2', 'N3'):
        add(r['id'], {'ours': 'opt_maxdelay', 'ours_n0': 'n0_maxdelay', 'casaal': 'casaal'}[r['variant']], r['verdict'], r['stored'], r['seconds'])
def key(k): return (k[0], int(re.sub(r'\D', '', k) or 0), k)
def ours(i): return res[i].get('opt_maxdelay') or res[i].get('opt_allcopy')
rows = []
for i in sorted(res, key=key):
    c = res[i].get('casaal'); o = ours(i)
    if c and o and c[0] == 'empty' and o[0] == 'empty':
        n0 = res[i].get('n0_maxdelay', o)
        rows.append((i, int(c[1]), int(o[1]), int(n0[1]), o[2], c[2]))
with open(os.path.join(D, 'tck_final.tsv'), 'w', encoding='utf8') as f:
    f.write('id\tcasaal\tours\tours_n0\tours_s\tcasaal_s\n')
    for r in rows: f.write('\t'.join(map(str, r)) + '\n')
def n(x): return '{:,}'.format(x)
L = []
for (i, c, o, n0, so, sc) in rows:
    L.append('%s & %s & %s & %s %s' % (i, n(c), n(o), n(n0), BS * 2))
tc = sum(r[1] for r in rows); to = sum(r[2] for r in rows)
fewer = sum(r[2] < r[1] for r in rows); eq = sum(r[2] == r[1] for r in rows); more = sum(r[2] > r[1] for r in rows)
tc2 = sum(r[1] for r in rows if r[0] != 'N4'); to2 = sum(r[2] for r in rows if r[0] != 'N4')
tex = (BS + 'begin{table}[t]\n' + BS + 'centering\n' + BS + 'caption{States stored by TChecker (' + BS + 'texttt{tck-liveness}, ' + BS + 'texttt{couvscc}) on the product of the negated requirement with a reference system, for the %d patterns where both runs completed (the product is empty, so it is explored completely and the count does not depend on the exploration order). The reference system is the automaton of the requirement itself, exported by our tool with the diagonal-free all-copy policy, because TChecker rejects diagonal guards. Columns: CASAAL' % len(rows) + "'" + 's automaton, our optimized automaton, and ours with the optimizer disabled (' + BS + 'texttt{-n 0}).}\n'
       + BS + 'label{tab:casaal-tck}\n' + BS + 'scriptsize\n' + BS + 'begin{tabular}{@{}lrrr@{}}\n' + BS + 'toprule\nPattern & CASAAL & Ours & Ours, ' + BS + 'texttt{-n 0} ' + BS * 2 + '\n' + BS + 'midrule\n'
       + '\n'.join(L) + '\n' + BS + 'midrule\nTotal & %s & %s & %s %s\n' % (n(tc), n(to), n(sum(r[3] for r in rows)), BS * 2)
       + BS + 'bottomrule\n' + BS + 'end{tabular}\n' + BS + 'end{table}\n')
open(os.path.join(D, 'casaal_tck_table.tex'), 'w', encoding='utf8').write(tex)
print(len(rows), 'products; ours', to, 'casaal', tc, 'fewer', fewer, 'equal', eq, 'more', more, 'ratio %.2f' % (tc / to), 'without N4: %d vs %d ratio %.2f' % (to2, tc2, tc2 / to2))
