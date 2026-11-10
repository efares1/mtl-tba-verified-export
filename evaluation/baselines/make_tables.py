"""Tables for the TChecker baselines (run after run_all.sh).
Writes baseline_ablation_table.tex (ref workload, 18 products) and baseline_posbad_table.tex."""
import csv, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))
B = chr(92)


def load(f):
    return list(csv.DictReader(open(os.path.join(HERE, f), encoding='utf8'), delimiter='\t'))


def table(f):
    d = collections.defaultdict(dict)
    for r in load(f):
        if r['verdict'] in ('empty', 'nonempty') and r['stored'].isdigit():
            d[r['id']][r['arm']] = int(r['stored'])
    return d


def fmt(n):
    return '{:,}'.format(n).replace(',', '{,}')


ARMS = [('ours', 'ours (default export)'), ('ours_noinv', 'ours, invariants removed'),
        ('casaal', "CASAAL, transition acceptance encoded by the adapter"),
        ('casaal_inv', 'CASAAL + invariant script'),
        ('casaal_exp', 'CASAAL converted to location acceptance, our export'),
        ('casaal_exp_noinv', 'same, invariants removed')]
d = table('baselines_ref.tsv')
ids = sorted(i for i in d if all(a in d[i] for a, _ in ARMS))
groups = [('all %d products' % len(ids), ids), ('F5--F8', [i for i in ('F5', 'F6', 'F7', 'F8') if i in ids]),
          ('F10--F12', [i for i in ('F10', 'F11', 'F12') if i in ids]), ('R3', ['R3'])]
L = [B + 'begin{tabular}{@{}lrrrr@{}}', B + 'toprule',
     'Automaton given to TChecker & ' + ' & '.join(g for g, _ in groups) + ' ' + B + B, B + 'midrule']
for a, name in ARMS:
    L.append(name + ' & ' + ' & '.join(fmt(sum(d[i][a] for i in ids_)) for _, ids_ in groups) + ' ' + B + B)
L += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'baseline_ablation_table.tex'), 'w').write('\n'.join(L) + '\n')

p = table('baselines_posbad_allcopy.tsv')
PA = [('ours', 'ours'), ('ours_noinv', 'ours, inv. removed'), ('casaal', 'CASAAL'),
      ('casaal_inv', 'CASAAL + script'), ('casaal_exp', 'CASAAL conv.')]
L = [B + 'begin{tabular}{@{}l' + 'r' * len(PA) + '@{}}', B + 'toprule', 'Requirement & ' + ' & '.join(n for _, n in PA) + ' ' + B + B, B + 'midrule']
for i in ('R1', 'R2', 'R3', 'R4', 'R5'):
    if i in p:
        L.append(i + ' & ' + ' & '.join(fmt(p[i][a]) if a in p[i] else '--' for a, _ in PA) + ' ' + B + B)
L += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'baseline_posbad_table.tex'), 'w').write('\n'.join(L) + '\n')
print(open(os.path.join(HERE, 'baseline_ablation_table.tex')).read())
print(open(os.path.join(HERE, 'baseline_posbad_table.tex')).read())
