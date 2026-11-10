"""Symbolic transition counts before and after the optimizer (Article 2).

Reads symbolic_before_after.raw (written by run_symbolic_before_after.sh: for
each benchmark configuration, `mtl2tba -n 0 -stats` and `mtl2tba -stats` at
Spot levels small and low) and writes symbolic_before_after.tsv and
symbolic_before_after_table.tex.

Columns of a -stats line (see `mtl2tba -stats-header`): 5 comp_locs, 6 comp_trans,
9 opt_locs, 10 opt_trans, 13 exp_trans, 17 opt_s, 18 exp_s, 19 total_s,
21 sym_trans (symbolic transitions of the exported automaton).
"""
import csv, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
cas = {}
with open(os.path.join(HERE, '..', '..', 'paper1_access', 'evaluation', 'casaal_exclusive.tsv'), encoding='utf-8') as f:
    for r in csv.DictReader((l for l in f if not l.startswith('#')), delimiter='\t'):
        if r.get('exact') == 'yes' and r.get('transitions'):
            cas[r['id']] = int(r['transitions'])
raw = {}
with open(os.path.join(HERE, 'symbolic_before_after.raw'), encoding='utf-8') as f:
    for l in f:
        m = re.match(r'^(\S+)\t(\S+)\t\[(.*?)\]\t\[(.*?)\]$', l.rstrip('\n'))
        if not m:
            continue
        a, b = m.group(3).split('\t'), m.group(4).split('\t')
        raw[(m.group(1), m.group(2))] = (a if len(a) >= 21 else None, b if len(b) >= 21 else None)
ids = []
for (i, lvl) in raw:
    if lvl == 'small' and i not in ids:
        ids.append(i)
out = []
for i in ids:
    a, b = raw[(i, 'small')]
    lo = raw.get((i, 'low'), (None, None))[1]
    if b is None:
        out.append(dict(id=i)); continue
    out.append(dict(id=i, compile_trans=b[5], sym_noopt=(a[20] if a else ''), sym_opt=b[20],
                    opt_trans=b[9], exp_trans=b[12], casaal=cas.get(i, ''),
                    total_s_small=b[18], total_s_low=(lo[18] if lo else '')))
cols = ['id', 'compile_trans', 'sym_noopt', 'sym_opt', 'opt_trans', 'exp_trans', 'casaal', 'total_s_small', 'total_s_low']
with open(os.path.join(HERE, 'symbolic_before_after.tsv'), 'w', encoding='utf-8') as f:
    f.write('\t'.join(cols) + '\n')
    for r in out:
        f.write('\t'.join(str(r.get(c, '')) for c in cols) + '\n')
def tot(rs, k):
    return sum(int(r[k]) for r in rs)
both = [r for r in out if r.get('sym_noopt') not in ('', None)]
print(f"configurations with both symbolic counts: {len(both)}; "
      f"symbolic no-opt {tot(both,'sym_noopt')} -> opt {tot(both,'sym_opt')}")
nof = [r for r in both if not r['id'].startswith('R')]
print(f"  F and N only ({len(nof)}): {tot(nof,'sym_noopt')} -> {tot(nof,'sym_opt')}")
rr = [r for r in both if r['id'].startswith('R')]
print(f"  R only ({len(rr)}): {tot(rr,'sym_noopt')} -> {tot(rr,'sym_opt')}")
nb = [r['id'] for r in out if r.get('compile_trans') and r.get('sym_noopt') in ('', None)]
print('  no-opt export did not finish within 300 s:', nb)
cm = [r for r in out if r.get('casaal') != '' and r.get('sym_opt')]
eq = sum(1 for r in cm if int(r['sym_opt']) == int(r['casaal'])); lt = sum(1 for r in cm if int(r['sym_opt']) < int(r['casaal'])); gt = sum(1 for r in cm if int(r['sym_opt']) > int(r['casaal']))
print(f"  vs CASAAL (exclusive) on {len(cm)} configurations: equal {eq}, smaller {lt}, larger {gt}")
print('  larger:', [(r['id'], r['sym_opt'], r['casaal']) for r in cm if int(r['sym_opt']) > int(r['casaal'])])

# LaTeX table for the supplement (BS is a backslash)
BS = chr(92)
def cell(x):
    return x if x not in ('', None) else '--'
L = []
L.append(BS + 'begin{table}[t]')
L.append(BS + 'centering')
L.append(BS + 'caption{Transitions before and after optimization. Comp.: explicit transitions of the optimizer input; '
         'Sym. no opt. and Sym. opt.: symbolic transitions of the exported automaton with the optimizer disabled '
         '(' + BS + 'texttt{-n 0}) and enabled; Opt.: explicit transitions after optimization; CASAAL: symbolic '
         'transitions of its output with mutually exclusive events (-- if not encodable). A bound of 300 s means that '
         'the unoptimized export did not finish within 300 seconds. R7 and R8 do not complete.}')
L.append(BS + 'label{tab:symbolic-before-after}')
L.append(BS + 'scriptsize')
L.append(BS + 'setlength{' + BS + 'tabcolsep}{4pt}')
L.append(BS + 'begin{tabular}{@{}lrrrrr@{}}')
L.append(BS + 'toprule')
L.append('ID & Comp. & Sym. no opt. & Sym. opt. & Opt. & CASAAL' + BS + BS)
L.append(BS + 'midrule')
for r in out:
    if not r.get('compile_trans'):
        continue
    sn = r['sym_noopt'] if r['sym_noopt'] != '' else '$>$300 s'
    L.append(' & '.join([r['id'], r['compile_trans'], sn, r['sym_opt'], r['opt_trans'], cell(str(r['casaal']))]) + BS + BS)
L.append(BS + 'bottomrule')
L.append(BS + 'end{tabular}')
L.append(BS + 'end{table}')
NL = chr(10)
open(os.path.join(HERE, 'symbolic_before_after_table.tex'), 'w', encoding='utf-8', newline=NL).write(NL.join(L) + NL)
