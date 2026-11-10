#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
run_dir=evaluation/runs/2026-10-10-split-export-v2
mkdir -p "$run_dir"
ocamlc -w -a -c tool/src/optim.ml -o tmp/optim.cmo
ocamlc -w -a -I tmp -o tmp/synthetic_tba_bench.exe \
  unix.cma tmp/optim.cmo evaluation/synthetic_tba_bench.ml
printf 'model\toptimize_rounds\tvariant\tlocations\treachable\ttransitions\tclocks\tresets\tguard_atoms\tinvariant_locations\tinvariant_atoms\tdifference_atoms\tsymbolic_transitions\tmean_seconds_200\n' \
  > "$run_dir/sizes.tsv"
printf 'model\tpeak_rss_kib\tmeasurement\n' > "$run_dir/memory.tsv"
for model in stable redundant_guard contradictory_guard unsatisfiable_label \
             isolated_source dead_reset normalization_dead_reset synchronous_clock_merge \
             duplicate_transition equivalent_locations \
             disjunctive_invariant_export backward_tightening \
             forward_lower_bound forward_contradiction_cascade \
             backward_contradiction_cascade \
             clock_merge_contradiction_cascade; do
  /usr/bin/time -f '%M' -o "$run_dir/current.rss" \
    tmp/synthetic_tba_bench.exe --compare-export "$model" \
    > "$run_dir/current.tsv"
  tail -n +2 "$run_dir/current.tsv" >> "$run_dir/sizes.tsv"
  printf '%s\t%s\t%s\n' "$model" "$(cat "$run_dir/current.rss")" \
    'paired max-delay/all-copy export in one process' >> "$run_dir/memory.tsv"
done
for k in 2 3 4 6; do
  model="invariant_disjunction_$k"
  /usr/bin/time -f '%M' -o "$run_dir/current.rss" \
    tmp/synthetic_tba_bench.exe --compare-parameterized "$model" \
    > "$run_dir/current.tsv"
  tail -n +2 "$run_dir/current.tsv" >> "$run_dir/sizes.tsv"
  printf '%s\t%s\t%s\n' "$model" "$(cat "$run_dir/current.rss")" \
    'paired max-delay/all-copy export in one process' >> "$run_dir/memory.tsv"
done
rm -f "$run_dir/current.rss" "$run_dir/current.tsv"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$run_dir/completed_utc.txt"
