#!/bin/bash
# Leave-one-out ablation of the optimization passes on the benchmark and the
# random formulas.  Needs a scratch build of the tool whose optimize_step
# skips the pass named in $ABLATE (the proved sources are not modified; see
# ABLATION.md).  Writes pass_ablation.tsv: one row per configuration and
# variant, with the post-optimization and exported sizes (after the same Spot
# automaton; each variant keeps language preservation, since every pass is
# proved separately).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-$HOME/ablate_tool/_build/default/src/mtl2tba.exe}
OUT=${OUT:-"$HERE/pass_ablation.tsv"}
LIMIT=${LIMIT:-120}
IDS=${IDS:-"F1 F2 F3 F3b F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 R1 R2 R3 R4 R5 N1 N2 N3 N4 N5"}
VARIANTS="none propagate forward contradictory unsat unreachable normalize dead_resets merge_clocks merge_trans merge_states"
W=$(mktemp -d); trap 'rm -rf -- "$W"' EXIT
printf 'id\tvariant\t' > "$OUT"
"$EXE" -stats-header -nopdf -o "$W/h" '[](p)' | head -1 >> "$OUT"
run() { # id formula
  for v in $VARIANTS; do
    if [ "$v" = none ]; then unset ABLATE; else export ABLATE=$v; fi
    row=$(cd "$W" && timeout "$LIMIT" "$EXE" -stats -nopdf -o "$W/o" "$2" 2>/dev/null | tail -1)
    printf '%s\t%s\t%s\n' "$1" "$v" "${row:-timeout}" >> "$OUT"
  done
  unset ABLATE
}
{ grep -v '^#' "$HERE/formulas.tsv" | awk -F'\t' '{print $1"\t"$3}'
  grep -v '^#' "$HERE/random_formulas.tsv" | awk -F'\t' '{print $1"\t"$2}'; } |
while IFS=$'\t' read -r id f; do
  case "$id" in X*) ;; *) [[ " $IDS " == *" $id "* ]] || continue;; esac
  run "$id" "$f"
done
echo done
