"""Summarize ours_runs.tsv into ours_results.tsv: sizes of the first run,
median, minimum, and maximum of the stage and total times, peak memory.
"""
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RUNS = sys.argv[1] if len(sys.argv) > 1 else 'ours_runs.tsv'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'ours_results.tsv'
rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, RUNS), encoding='utf-8')]
hdr, rows = rows[0], rows[1:]
by_id = {}
for r in rows:
    by_id.setdefault(r[0], []).append(dict(zip(hdr, r)))
times = ['spot_s', 'opt_s', 'exp_s', 'total_s']
out_hdr = ['id', 'status'] + [h for h in hdr[4:] if h not in times] + \
    [f'{t}_med' for t in times] + ['total_s_min', 'total_s_max', 'mem_mb', 'runs']
with open(os.path.join(HERE, OUT), 'w', encoding='utf-8', newline='\n') as f:
    f.write('\t'.join(out_hdr) + '\n')
    for fid, runs in by_id.items():
        ok = [r for r in runs if r['status'] == 'ok']
        if not ok:
            f.write(f'{fid}\t{runs[0]["status"]}\n')
            continue
        first = ok[0]
        vals = [fid, 'ok'] + [first[h] for h in hdr[4:] if h not in times]
        for t in times:
            vals.append('%.3f' % statistics.median(float(r[t]) for r in ok))
        tot = [float(r['total_s']) for r in ok]
        vals += ['%.3f' % min(tot), '%.3f' % max(tot),
                 '%.1f' % (max(int(r['mem_kb']) for r in ok) / 1024), str(len(ok))]
        f.write('\t'.join(vals) + '\n')
print(OUT, 'written')
