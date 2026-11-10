#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
run_dir=evaluation/runs/2026-10-10-synthetic-ablation
mkdir -p "$run_dir"
ocamlc -w -a -I +unix -c tool/src/optim.ml -o tmp/optim.cmo
ocamlc -w -a -I +unix -I tmp -o tmp/synthetic_tba_bench.exe \
  unix.cma tmp/optim.cmo evaluation/synthetic_tba_bench.ml
tmp/synthetic_tba_bench.exe > "$run_dir/pass_trace.tsv"
tmp/synthetic_tba_bench.exe --ablation > "$run_dir/leave_one_out.tsv"
tmp/synthetic_tba_bench.exe --parameterized > "$run_dir/parameterized_trace.tsv"
printf 'model\tpeak_rss_kib\tmeasurement\n' > "$run_dir/memory.tsv"
for model in stable redundant_guard contradictory_guard unsatisfiable_label \
             isolated_source dead_reset synchronous_clock_merge \
             duplicate_transition equivalent_locations \
             disjunctive_invariant_export backward_tightening \
             forward_lower_bound forward_contradiction_cascade \
             backward_contradiction_cascade clock_merge_contradiction_cascade; do
  /usr/bin/time -f '%M' -o "$run_dir/current.rss" \
    tmp/synthetic_tba_bench.exe "$model" >/dev/null 2>/dev/null
  printf '%s\t%s\t%s\n' "$model" "$(cat "$run_dir/current.rss")" \
    'single-model process, includes 200 timing repetitions' >> "$run_dir/memory.tsv"
done
rm -f "$run_dir/current.rss"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$run_dir/completed_utc.txt"
