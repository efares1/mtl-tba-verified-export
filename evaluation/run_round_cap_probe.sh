#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RUN=${RUN:-evaluation/runs/2026-10-10-round-cap-v4}
mkdir -p "$RUN"
RUN="$(cd "$RUN" && pwd)"
(
  cd tool
  dune build
)
ocamlc -w -a -I +unix -c tool/src/optim.ml -o tmp/optim.cmo
ocamlc -w -a -I +unix -I tmp -o tmp/synthetic_tba_bench.exe \
  unix.cma tmp/optim.cmo evaluation/synthetic_tba_bench.ml
tmp/synthetic_tba_bench.exe --cap-probe unreachable_cascade_51 \
  > "$RUN/probe51.tsv"
tmp/synthetic_tba_bench.exe --cap-probe unreachable_cascade_50 \
  > "$RUN/probe50.tsv"
tmp/synthetic_tba_bench.exe --cap-probe unreachable_cascade_64 \
  > "$RUN/probe64.tsv"
printf 'requested_rounds\tstatus\twarning\n' > "$RUN/driver.tsv"
for rounds in 1 2 50; do
  base="$RUN/R2_n$rounds"
  (cd "$RUN" && "$ROOT/tool/_build/default/src/mtl2tba.exe" \
    -n "$rounds" -stats -nopdf -o "R2_n$rounds" \
    '[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2)' \
    > "$base.stdout" 2> "$base.stderr")
  if grep -q 'round cap reached' "$base.stderr"; then
    status=cap_warning
    warning=yes
  else
    status=quiet
    warning=no
  fi
  printf '%s\t%s\t%s\n' "$rounds" "$status" "$warning" \
    >> "$RUN/driver.tsv"
done
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$RUN/completed_utc.txt"
