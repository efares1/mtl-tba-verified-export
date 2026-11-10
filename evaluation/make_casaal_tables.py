"""LaTeX tables comparing CASAAL with mtl2tba (automatic mode and, where it
is faster, a manual setting) and the TChecker cost table.  Reads
auto_times.tsv, level_feature_check.tsv, casaal_time.tsv,
neg_sizes_vs_casaal.tsv, tck_cost_vs_casaal.tsv; writes casaal_gen_table.tex,
casaal_tck_table.tex and casaal_summary.txt."""
import csv, os, collections
EOL = chr(92) * 2
D = os.path.dirname(os.path.abspath(__file__))
def rd(f): return list(csv.DictReader(open(os.path.join(D, f), encoding='utf-8'), delimiter='\t'))

auto = {(r['id'], r['pol']): r for r in rd('auto_times.tsv')}
lv = {(r['id'], r['pol'], r['config']): r for r in rd('level_feature_check.tsv')}
cas_t = {r['id']: float(r['best_s']) for r in rd('casaal_time.tsv') if r['status'] == 'ok'}
neg = collections.defaultdict(dict)
for r in rd('neg_sizes_vs_casaal.tsv'): neg[r['id']][r['tool']] = r
# N8 negated, measured alone (n8_final.tsv): auto and manual (-simp -spot-level any)
for r in rd('n8_final.tsv'):
    if r['status'] != 'ok': continue
    if r['config'] == 'auto':
        auto[('N8', 'neg')] = dict(status='ok', seconds=r['seconds'], fallback=r['fallback'], locs=r['locs'], trans=r['trans'])
    else:
        lv[('N8', 'neg', 'any')] = dict(status='ok', seconds=r['seconds'])
# extra single runs measured separately (seconds), see the text: N7 negated, explicit settings
EXTRA = {('N8', 'neg', 'any'): None}

def fmt(x):
    return '%.1f' % x if x >= 0.095 else '%.2f' % x if x >= 0.01 else '<0.01'

def manual(i, pol, a_secs):
    best = None
    for cfg, label in (('low', r'\texttt{low}'), ('any', r'\texttt{any}')):
        r = lv.get((i, pol, cfg))
        if r and r['status'] == 'ok':
            s = float(r['seconds'])
            if best is None or s < best[0]: best = (s, label)
    if best and best[0] < 0.9 * a_secs and a_secs - best[0] >= 0.1:
        return '%s (%s)' % (fmt(best[0]), best[1])
    return '--'

rows = [i for i in ['R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8', 'N5', 'N6', 'N7', 'N8']]
out = []
for i in rows:
    n = neg[i]
    c = n.get('casaal'); ct = cas_t.get(i)
    a = auto.get((i, 'neg'))
    locs_tr_c = '%s/%s' % (c['locs'], c['trans']) if c and c['locs'] else '--'
    if a and a['status'] == 'ok':
        loctr = '%s/%s' % (a['locs'], a['trans'])
        asec = float(a['seconds']); atxt = fmt(asec) + (r'$^{\dagger}$' if a['fallback'] == '1' else '')
        man = manual(i, 'neg', asec)
    elif a:
        loctr = '--'; atxt = r'$>$%d' % int(float(a['seconds'])); man = '--'
    else:
        loctr = '--'; atxt = 'pending'; man = '--'
    out.append(('%s & %s & %s & %s & %s & %s ' + EOL) % (i, locs_tr_c, loctr, fmt(ct) if ct else '--', atxt, man))
tab = r'''\begin{table*}[t]
\centering
\caption{Negated requirements: CASAAL against \texttt{mtl2tba}. Size is reachable locations/transitions of the automaton given to the model checker (ours: after optimization). Times are wall-clock seconds for the whole translation (generation plus, for ours, optimization and export), CASAAL on native Windows and \texttt{mtl2tba} under WSL~2 on the same machine. ``Auto'' is the default of the tool; $^{\dagger}$ marks runs where Spot had not finished within the 5~s budget and the tool fell back to \texttt{any} on the simplified formula. The last column gives the time of the fastest explicit setting when it is at least 10\% and 0.1~s faster than auto: 	exttt{low}, or 	exttt{-simp -spot-level any -spot-x ba-simul=0}, written 	exttt{any}; the sizes of the automata are the same for both settings except where noted in the text.}
\label{tab:casaal-gen}
\scriptsize
\setlength{\tabcolsep}{4pt}
\begin{tabular}{@{}lrrrrr@{}}
\toprule
 & CASAAL size & Ours size & CASAAL time & Ours, auto & Ours, manual (setting)\\
\midrule
''' + '\n'.join(out) + r'''
\bottomrule
\end{tabular}
\end{table*}
'''
open(os.path.join(D, 'casaal_gen_table.tex'), 'w', encoding='utf-8').write(tab)

# TChecker table
tck = collections.defaultdict(dict)
for r in rd('tck_cost_vs_casaal.tsv'): tck[r['id']][r['variant']] = r
lines = []; so = sc = 0; fewer = eq = more = 0; skipped = []
for i, v in tck.items():
    o, c, n0 = v['ours'], v['casaal'], v.get('ours_n0')
    if o['stored'] == 'NA' or c['stored'] == 'NA':
        skipped.append(i); continue
    a, b = int(o['stored']), int(c['stored']); so += a; sc += b
    fewer += a < b; more += a > b; eq += a == b
    lines.append(('%s & %s & %s & %s & %s ' + EOL) % (i, '{:,}'.format(b), '{:,}'.format(a),
                 '{:,}'.format(int(n0['stored'])) if n0 and n0['stored'] != 'NA' else '--', o['verdict']))
tt = r'''\begin{table}[t]
\centering
\caption{States stored by TChecker (\texttt{tck-liveness}, \texttt{couvscc}) on the product of the negated requirement with a fixed system, for the 16 patterns where all three runs completed (verdict ``empty'': the whole product is explored, so the count is independent of the exploration order). CASAAL's automaton, our optimized automaton, and ours with the optimizer disabled (\texttt{-n 0}).}
\label{tab:casaal-tck}
\scriptsize
\begin{tabular}{@{}lrrrl@{}}
\toprule
Pattern & CASAAL & Ours & Ours, \texttt{-n 0} & Verdict\\
\midrule
''' + '\n'.join(lines) + r'''
\midrule
Total & %s & %s & & \\
\bottomrule
\end{tabular}
\end{table}
''' % ('{:,}'.format(sc), '{:,}'.format(so))
open(os.path.join(D, 'casaal_tck_table.tex'), 'w', encoding='utf-8').write(tt)
open(os.path.join(D, 'casaal_summary.txt'), 'w').write(
    'tck: ours %d casaal %d fewer %d equal %d more %d skipped %s\n' % (so, sc, fewer, eq, more, ','.join(skipped)))
print(open(os.path.join(D, 'casaal_summary.txt')).read())
