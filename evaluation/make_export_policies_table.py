"""LaTeX table of the two export policies, from export_policies.tsv.

    python3 make_export_policies_table.py   ->  export_policies_table.tex

export_policies.tsv is written by run_export_policies.sh.  Rows whose run did
not complete (R7, R8) are printed with dashes.
"""
import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
rows = list(csv.DictReader(open(os.path.join(HERE, 'export_policies.tsv'), encoding='utf-8'), delimiter='\t'))

out = []
out.append(r'\begin{table}[t]')
out.append(r'\centering')
out.append(r'\caption{Both export policies on every configuration. Opt.: transitions of the optimized '
           r'automaton. Max.-delay (default) and all-copy: transitions, invariants, and difference guards '
           r'of the exported automaton. R7 and R8 do not complete within 300~s.}')
out.append(r'\label{tab:export-policies}')
out.append(r'\scriptsize\setlength{\tabcolsep}{4pt}')
out.append(r'\begin{tabular}{@{}lrrrrrrr@{}}')
out.append(r'\toprule')
out.append(r'ID & Opt. & \multicolumn{3}{c}{Max.-delay} & \multicolumn{3}{c}{All-copy}\\')
out.append(r'\cmidrule(lr){3-5}\cmidrule(l){6-8}')
out.append(r'& & Trans. & Inv. & Diff. & Trans. & Inv. & Diff.\\')
out.append(r'\midrule')
for r in rows:
    if r['md_status'] == 'ok' and r['ac_status'] == 'ok':
        cells = [r['id'], r['opt_trans'], r['md_trans'], r['md_invs'], r['md_diffs'],
                 r['ac_trans'], r['ac_invs'], r['ac_diffs']]
    else:
        cells = [r['id']] + ['--'] * 7
    out.append(' & '.join(cells) + r'\\')
out.append(r'\bottomrule')
out.append(r'\end{tabular}')
out.append(r'\end{table}')
with open(os.path.join(HERE, 'export_policies_table.tex'), 'w', encoding='utf-8', newline='') as f:
    f.write('\r\n'.join(out) + '\r\n')
ok = [r for r in rows if r['md_status'] == 'ok']
print('rows', len(rows), 'completed', len(ok),
      'sum opt', sum(int(r['opt_trans']) for r in ok), 'sum max-delay', sum(int(r['md_trans']) for r in ok))
