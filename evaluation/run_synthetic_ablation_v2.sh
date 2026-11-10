#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RUN=${RUN:-evaluation/runs/2026-10-10-synthetic-ablation-v2}
mkdir -p "$RUN"
{
  date -u +'%Y-%m-%dT%H:%M:%SZ'
  printf 'user: '; id -un
  printf 'kernel: '; uname -r
  ocaml -version
  ocamlc -version
} > "$RUN/provenance.txt" 2>&1
sha256sum tool/src/optim.ml evaluation/synthetic_tba_bench.ml \
  > "$RUN/source_sha256.txt"
ocamlc -w -a -I +unix -c tool/src/optim.ml -o tmp/optim.cmo
ocamlc -w -a -I +unix -I tmp -o tmp/synthetic_tba_bench.exe \
  unix.cma tmp/optim.cmo evaluation/synthetic_tba_bench.ml
tmp/synthetic_tba_bench.exe > "$RUN/pass_trace.tsv"
tmp/synthetic_tba_bench.exe --ablation > "$RUN/leave_one_out.tsv"
tmp/synthetic_tba_bench.exe --parameterized > "$RUN/parameterized_trace.tsv"
{
  for model in backward_tightening forward_lower_bound normalization_dead_reset \
               forward_contradiction_cascade backward_contradiction_cascade \
               clock_merge_contradiction_cascade; do
    tmp/synthetic_tba_bench.exe --describe "$model"
  done
} > "$RUN/mechanism_examples.txt"
printf 'model\tpeak_rss_kib\tmeasurement\n' > "$RUN/memory.tsv"
for model in stable redundant_guard contradictory_guard unsatisfiable_label \
             isolated_source dead_reset normalization_dead_reset synchronous_clock_merge \
             duplicate_transition equivalent_locations \
             disjunctive_invariant_export backward_tightening \
             forward_lower_bound forward_contradiction_cascade \
             backward_contradiction_cascade clock_merge_contradiction_cascade; do
  /usr/bin/time -f '%M' -o "$RUN/current.rss" \
    tmp/synthetic_tba_bench.exe "$model" >/dev/null 2>/dev/null
  printf '%s\t%s\t%s\n' "$model" "$(cat "$RUN/current.rss")" \
    'single-model process, includes 200 timing repetitions' >> "$RUN/memory.tsv"
done
rm -f "$RUN/current.rss"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$RUN/completed_utc.txt"
