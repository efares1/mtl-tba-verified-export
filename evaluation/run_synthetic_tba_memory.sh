#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tmp
out=evaluation/synthetic_tba_memory.tsv
printf 'model\tpeak_rss_kib\tmeasurement\n' > "$out"
for model in stable redundant_guard contradictory_guard unsatisfiable_label \
             isolated_source dead_reset synchronous_clock_merge \
             duplicate_transition equivalent_locations \
             disjunctive_invariant_export; do
  rss_file="tmp/synthetic_tba_${model}.rss"
  /usr/bin/time -f '%M' -o "$rss_file" \
    tmp/synthetic_tba_bench.exe "$model" >/dev/null 2>/dev/null
  printf '%s\t%s\t%s\n' "$model" "$(cat "$rss_file")" \
    'single-model process, includes 200 timing repetitions' >> "$out"
done
