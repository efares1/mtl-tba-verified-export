"""Run the tests T1 (regression on outputs) and T2 (bounded language test) on built mutants.
Run inside WSL:   python3 run_mutants.py [ID ...]      (needs ~/mut/exe/<ID>_{tba_opt,mtl2tba}.exe)
Results: results/<ID>.json"""
import os, sys, json, shutil, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mut_lib import *
import bench

BUDGETS = [(1000, 1000, 11), (20000, 20000, 12), (100000, 20000, 13)]  # (words per corpus input, words per benchmark input, seed)
RES = os.path.join(HERE, 'results')
os.makedirs(RES, exist_ok=True)

gold_c = HOME + '/mut/out/base'
gold_b = HOME + '/mut/out/bench_base'


def ensure_gold():
    if not os.path.isdir(gold_c) or not os.listdir(gold_c):
        shutil.rmtree(gold_c, ignore_errors=True)
        run_corpus(HOME + '/mut/exe/base_tba_opt.exe', gold_c)
    if not os.path.isdir(gold_b) or not os.listdir(gold_b):
        shutil.rmtree(gold_b, ignore_errors=True)
        exe = HOME + '/mut/exe/base_mtl2tba.exe'
        bench.run_bench(exe, gold_b, ['-n', '0'], 'n0')
        bench.run_all(exe, gold_b)


def summarize(res):
    """res: dict key -> (mismatch, first, accA); negative mismatch = crash/unparsable output"""
    bad = {k: v for k, v in res.items() if v[0] != 0}
    return bad


def run_one(mid):
    t0 = time.time()
    out = {'id': mid}
    # ---- corpus (tba_opt) ----
    exe = HOME + '/mut/exe/%s_tba_opt.exe' % mid
    mdir = HOME + '/mut/out/' + mid
    shutil.rmtree(mdir, ignore_errors=True)
    st = run_corpus(exe, mdir)
    stg = {k: 0 for k in st}  # gold statuses are all 0 (checked by validate_oracle)
    d1 = compare_outputs(gold_c, mdir, stg, st)
    out['T1_corpus_changed'] = len(d1)
    out['corpus_runs'] = len(st)
    out['crashes'] = sum(1 for v in st.values() if v != 0)
    # ---- benchmark (mtl2tba) ----
    bdir = HOME + '/mut/out/bench_' + mid
    shutil.rmtree(bdir, ignore_errors=True)
    bst = bench.run_all(HOME + '/mut/exe/%s_mtl2tba.exe' % mid, bdir)
    out['bench_crashes'] = sum(1 for v in bst.values() if v != 0)
    work = HOME + '/mut/work_' + mid
    shutil.rmtree(work, ignore_errors=True)
    out['T2_corpus'] = None; out['T2_bench'] = None
    bdiff = None
    for (n, nb, seed) in BUDGETS:
        res = lang_check(mdir, n, seed, work + '_c')
        bad = summarize(res)
        bb, lb = bench.compare_bench(gold_b, bdir, nb, seed, work + '_b')
        if bdiff is None:
            bdiff = bb; out['T1_bench_changed'] = len(bb); out['bench_runs'] = len(lb)
        badb = {k: v for k, v in lb.items() if v[0] != 0}
        out['budget_tried'] = n
        if bad or badb:
            firsts = [v[1] for v in bad.values() if v[1] >= 0]
            out['T2_corpus'] = {'budget': n, 'inputs_with_mismatch': len(bad), 'min_first_word': min(firsts) if firsts else None,
                                'example': sorted(['%s/%s' % k for k in bad])[:4], 'unreadable_output': sum(1 for v in bad.values() if v[0] < 0)}
            firsts = [v[1] for v in badb.values() if v[1] >= 0]
            out['T2_bench'] = {'budget': nb, 'inputs_with_mismatch': len(badb), 'min_first_word': min(firsts) if firsts else None,
                               'example': sorted(['%s/%s/%s' % k for k in badb])[:4]}
            break
    out['seconds'] = round(time.time() - t0)
    json.dump(out, open(os.path.join(RES, mid + '.json'), 'w'), indent=1)
    print(json.dumps(out), flush=True)


if __name__ == '__main__':
    ensure_gold()
    ids = sys.argv[1:]
    for mid in ids:
        run_one(mid)
