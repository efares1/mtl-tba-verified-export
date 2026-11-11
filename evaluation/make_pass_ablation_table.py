"""Summarize pass_ablation.tsv (run_pass_ablation.sh): per skipped pass, the totals over the benchmark
group (F, R, N configurations that complete) and the random formulas, and the number of configurations
whose optimized size (locations, transitions, clocks) or exported size differs from the full optimizer."""
import csv, collections, sys
rows = list(csv.DictReader(open('pass_ablation.tsv', encoding='utf8'), delimiter='\t'))
grp = lambda i: 'random' if i.startswith('X') else 'benchmark'
by = collections.defaultdict(dict)
for r in rows:
    by[(grp(r['id']), r['variant'])][r['id']] = r
order = ['none', 'propagate', 'forward', 'contradictory', 'unsat', 'unreachable', 'normalize',
         'dead_resets', 'merge_clocks', 'merge_trans', 'merge_states']
num = lambda r, k: int(r[k])
out = []
for g in ('benchmark', 'random'):
    base = by[(g, 'none')]
    for v in order:
        cur = by[(g, v)]
        ids = [i for i in base if i in cur and base[i]['opt_locs'] != '' and cur[i]['opt_locs'] != '']
        tot = lambda k: sum(num(cur[i], k) for i in ids)
        diff = sum(1 for i in ids if any(cur[i][k] != base[i][k] for k in ('opt_locs', 'opt_trans', 'opt_clocks')))
        diffe = sum(1 for i in ids if any(cur[i][k] != base[i][k] for k in ('exp_locs', 'exp_trans', 'exp_invs', 'exp_clocks')))
        out.append((g, v, len(ids), tot('opt_locs'), tot('opt_trans'), tot('opt_clocks'), tot('exp_locs'),
                    tot('exp_trans'), tot('exp_invs'), diff, diffe))
hdr = 'group variant n opt_locs opt_trans opt_clocks exp_locs exp_trans exp_invs changed_opt changed_exp'.split()
print('\t'.join(hdr))
for o in out: print('\t'.join(map(str, o)))
open('pass_ablation_summary.tsv', 'w').write('\t'.join(hdr) + '\n' + '\n'.join('\t'.join(map(str, o)) for o in out) + '\n')

# LaTeX table for the supplement
names = {'none': 'none (full optimizer)', 'propagate': 'invariant propagation', 'forward': 'forward bound propagation',
         'contradictory': 'contradictory guards', 'unsat': 'unsatisfiable guards', 'unreachable': 'unreachable locations',
         'normalize': 'guard normalization', 'dead_resets': 'dead resets', 'merge_clocks': 'clock merging',
         'merge_trans': 'transition merging', 'merge_states': 'location merging'}
b = {o[1]: o for o in out if o[0] == 'benchmark'}
r = {o[1]: o for o in out if o[0] == 'random'}
fmt = lambda n: '{:,}'.format(n).replace(',', '{,}')
L = []
for v in order:
    x, y = b[v], r[v]
    EOL = chr(92) * 2  # LaTeX row end
    L.append('%s & %s & %s & %d & %d & %s & %s & %d & %d ' % (
        names[v], fmt(x[4]), fmt(x[3]), x[5], x[9], fmt(y[4]), fmt(y[3]), y[5], y[9]) + EOL)
# the row end of the last row is written by the including file: a row end at the end of an
# \input file makes the following \bottomrule misplaced
open('pass_ablation_table.tex', 'w').write('\n'.join(L)[:-2].rstrip() + '\n')
