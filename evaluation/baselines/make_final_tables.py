"""Tables of the TChecker comparison with CASAAL converted to location acceptance, and of the
same-driver generation times. Writes (next to this script's parent):
  evaluation/baselines/tck_summary_table.tex   (article: totals over the 18 products and subsets)
  evaluation/casaal_tck_table.tex              (supplement: per product)
  evaluation/baselines/baseline_posbad_table.tex (supplement: positive-form workload)
  evaluation/baselines/same_driver_table.tex   (article: medians of five runs, one driver)
Usage: python make_final_tables.py   (run from any directory)"""
import csv, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))
EVAL = os.path.dirname(HERE)
B = chr(92)


def load(f):
    return list(csv.DictReader(open(os.path.join(HERE, f), encoding='utf8'), delimiter='\t'))


def stored(f):
    d = collections.defaultdict(dict)
    for r in load(f):
        if r['verdict'] in ('empty', 'nonempty') and r['stored'].isdigit():
            d[r['id']][r['arm']] = int(r['stored'])
    return d


def fmt(n):
    return '{:,}'.format(n).replace(',', '{,}')


def key(i):
    return (i[0], int(''.join(c for c in i[1:] if c.isdigit())), i)


# ---------- TChecker, empty products ----------
d = stored('baselines_ref.tsv')
NEED = ('ours', 'ours_n0', 'ours_noinv', 'casaal_exp', 'casaal_exp_noinv')
ids = sorted((i for i in d if all(a in d[i] for a in NEED)), key=key)
assert len(ids) == 18, ids
groups = [('all %d products' % len(ids), ids),
          ('F5--F8', [i for i in ('F5', 'F6', 'F7', 'F8')]),
          ('F10--F12', [i for i in ('F10', 'F11', 'F12')]),
          ('R3', ['R3'])]
ARMS = [('ours', 'ours (default)'), ('ours_n0', 'ours, optimizer disabled'),
        ('ours_noinv', 'ours, invariants removed'),
        ('casaal_exp', 'CASAAL, location acceptance'),
        ('casaal_exp_noinv', 'same, invariants removed')]
L = [B + 'begin{tabular}{@{}lrrrr@{}}', B + 'toprule',
     'Automaton given to TChecker & ' + ' & '.join(g for g, _ in groups) + ' ' + B + B, B + 'midrule']
for a, name in ARMS:
    L.append(name + ' & ' + ' & '.join(fmt(sum(d[i][a] for i in g)) for _, g in groups) + ' ' + B + B)
L += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'tck_summary_table.tex'), 'w').write('\n'.join(L) + '\n')

# per product table (supplement)
def pname(i):
    return i
cap = ("States stored by TChecker (" + B + "texttt{tck-liveness}, " + B + "texttt{couvscc}) on the product of the negated requirement "
       "with a reference system, for the 18 patterns on which every variant completed (F1--F12 with F3b in place of F3, R1--R3, N1--N3). "
       "The product is empty, so it is explored completely and the count does not depend on the exploration order. The reference system "
       "is the automaton of the requirement itself, exported with the diagonal-free all-copy policy because TChecker rejects diagonal guards. "
       "Columns: our optimized automaton, CASAAL's automaton converted to location acceptance and exported by our tool, our automaton with the "
       "optimizer disabled (" + B + "texttt{-n 0}), and with all location invariants removed. "
       "F14 (three acceptance sets) is not converted and N4 was not completed by the comparison driver, so neither is included.")
T = [B + 'begin{table}[tp]', B + 'centering', B + 'caption{' + cap + '}', B + 'label{tab:casaal-tck}', B + 'scriptsize',
     B + 'begin{tabular}{@{}lrrrr@{}}', B + 'toprule',
     'Pattern & Ours & CASAAL, converted & Ours, ' + B + 'texttt{-n 0} & Ours, no invariants ' + B + B, B + 'midrule']
tot = [0, 0, 0, 0]
for i in ids:
    row = [d[i]['ours'], d[i]['casaal_exp'], d[i]['ours_n0'], d[i]['ours_noinv']]
    tot = [t + r for t, r in zip(tot, row)]
    T.append(i + ' & ' + ' & '.join(fmt(r) for r in row) + ' ' + B + B)
T += [B + 'midrule', 'Total & ' + ' & '.join(fmt(t) for t in tot) + ' ' + B + B, B + 'bottomrule', B + 'end{tabular}', B + 'end{table}']
open(os.path.join(EVAL, 'casaal_tck_table.tex'), 'w').write('\n'.join(T) + '\n')

# ---------- positive-form workload ----------
p = stored('baselines_posbad_allcopy.tsv')
PA = [('ours', 'ours'), ('ours_noinv', 'ours, no invariants'), ('casaal_exp', 'CASAAL, location acceptance')]
L = [B + 'begin{tabular}{@{}l' + 'r' * len(PA) + '@{}}', B + 'toprule',
     'Requirement & ' + ' & '.join(n for _, n in PA) + ' ' + B + B, B + 'midrule']
for i in ('R1', 'R2', 'R3', 'R4', 'R5'):
    L.append(i + ' & ' + ' & '.join(fmt(p[i][a]) if a in p[i] else '--' for a, _ in PA) + ' ' + B + B)
L += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'baseline_posbad_table.tex'), 'w').write('\n'.join(L) + '\n')

# ---------- same-driver generation times ----------
td = {(r['id'], r['tool']): r for r in load('timing_same_driver.tsv')}
sizes = {'R2': ('4/8', '4/8'), 'R3': ('5/11', '5/11'), 'R5': ('7/17', '7/17'), 'R7': ('9/23', '9/23'), 'R8': ('10/26', '10/26'),
         'N5': ('33/461', '33/461'), 'N6': ('65/1541', '65/1541'), 'N7': ('129/5105', '129/5105'), 'N8': ('257/16769', '257/16769')}


def ft(x):
    x = float(x)
    return ('%.2f' % x) if x < 10 else (('%.1f' % x) if x < 100 else ('%.0f' % x))


L = [B + 'begin{tabular}{@{}lrrrr@{}}', B + 'toprule',
     'Pattern & CASAAL size & Ours size & CASAAL (s) & Ours, auto (s) ' + B + B, B + 'midrule']
for i in ('R2', 'R3', 'R5', 'R7', 'R8', 'N5', 'N6', 'N7', 'N8'):
    sc, so = sizes[i]
    L.append('%s & %s & %s & %s & %s ' % (i, sc, so, ft(td[(i, 'casaal')]['median_s']), ft(td[(i, 'ours')]['median_s'])) + B + B)
L += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'same_driver_table.tex'), 'w').write('\n'.join(L) + '\n')
print('ok', tot)
