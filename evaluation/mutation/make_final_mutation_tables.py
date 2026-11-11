"""Regenerate mutation_table.tex (22 mutants: baseline tests, large fuzz, Rocq) and rocq/rocq_rejection_table.tex.
Inputs: the previous mutation_table.tex rows (description, T1, T2 columns; kept in mutation_table_rows.txt after the first run),
results/fuzz_large.tsv, rocq/logs/*_result.json and logs.  Run natively (python make_final_mutation_tables.py)."""
import csv, json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
B = chr(92)
rows_file = os.path.join(HERE, 'mutation_table_rows.txt')
if not os.path.exists(rows_file):
    old = open(os.path.join(HERE, 'mutation_table.tex'), encoding='utf8').read().split('\n')
    keep = [l for l in old if re.match(r'M\d\d & ', l)]
    open(rows_file, 'w', encoding='utf8').write('\n'.join(keep) + '\n')
rows = {}
for l in open(rows_file, encoding='utf8').read().strip().split('\n'):
    p = [x.strip() for x in l.rstrip().rstrip(B + B).split(' & ')]
    rows[p[0]] = p  # id, desc, T1, T2, outcome
fz = {}
for r in csv.DictReader(open(os.path.join(HERE, 'results', 'fuzz_large.tsv'), encoding='utf8'), delimiter='\t'):
    fz[r['id']] = (int(r['inputs_changed_output']), int(r['inputs_language_mismatch']))

CAUGHT = 'M02 M03 M04 M06 M07 M09 M11 M13 M14 M15 M18 M19 M20'.split()
FUZZ_ONLY = 'M01 M10 M16 M17'.split()
ALL_MISS = ['M12']
NOCHG = 'M05 M08 M21 M22'.split()
out = {}
for m in rows:
    if m in CAUGHT: out[m] = 'caught'
    elif m in FUZZ_ONLY: out[m] = 'missed by T1, T2'
    elif m in ALL_MISS: out[m] = B + 'textbf{missed by all tests}'
    elif m in NOCHG: out[m] = 'no change found'
    else: raise SystemExit(m)

# Rocq results
RJ = os.path.join(HERE, 'rocq', 'logs')


def rocq(m):
    r = json.load(open(os.path.join(RJ, m + '_result.json')))
    assert r['status'] == 'rejected', (m, r['status'])
    g = r['failing_file']
    log = open(os.path.join(RJ, '%s_%s.log' % (m, g)), encoding='utf8', errors='replace').read().replace('\r', '')
    err = None
    for b in re.split(r'(?=^File ")', log, flags=re.M):
        if 'Error' in b[:600]:
            err = b; break
    line = int(re.search(r'line (\d+)', err).group(1))
    src = open(os.path.join(HERE, 'rocq', 'mut', m, g + '.v'), encoding='utf8', errors='replace').read().replace('\r', '').split('\n')
    name = None
    for i in range(min(line, len(src)) - 1, -1, -1):
        mm = re.match(r"\s*(?:Lemma|Theorem|Corollary|Definition|Fixpoint)\s+([A-Za-z0-9_']+)", src[i])
        if mm:
            name = mm.group(1); break
    return name, r['seconds_to_fail']


desc_rocq = {}
for l in open(os.path.join(HERE, 'rocq', 'more_mutants.py'), encoding='utf8'):
    pass
RC = {m: rocq(m) for m in rows}

T = [B + 'begin{tabular}{@{}lp{0.34'+B+'textwidth}rrrp{0.13'+B+'textwidth}l@{}}', B + 'toprule',
     'Mutant & Seeded defect (pass) & T1 & T2 first word & Fuzz & Outcome of the tests & Rocq ' + B + B, B + 'midrule']
for m in sorted(rows):
    p = rows[m]
    ch, bad = fz[m]
    T.append('%s & %s & %s & %s & %d/%d & %s & rejected %s' % (m, p[1], p[2], p[3], bad, ch, out[m], B + B))
T += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'mutation_table.tex'), 'w', encoding='utf8').write('\n'.join(T) + '\n')

order = 'M01 M10 M12 M16 M17'.split() + [m for m in sorted(rows) if m not in 'M01 M10 M12 M16 M17'.split()]
R = [B + 'begin{tabular}{@{}llr@{}}', B + 'toprule', 'Mutant & First failing lemma & Time (s) ' + B + B, B + 'midrule']
for i, m in enumerate(order):
    if i == 5:
        R.append(B + 'midrule')
    n, t = RC[m]
    R.append('%s & %s%s{%s} & %.1f %s' % (m, B, 'texttt', n.replace('_', B + '_'), t, B + B))
R += [B + 'bottomrule', B + 'end{tabular}']
open(os.path.join(HERE, 'rocq', 'rocq_rejection_table.tex'), 'w', encoding='utf8').write('\n'.join(R) + '\n')
print('ok')
