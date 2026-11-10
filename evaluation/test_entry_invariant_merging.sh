#!/bin/bash
# Regression test for the merging of locations under the entry invariant
# (merge_states_all, Rocq: merge_states_all_accepts).  Run in WSL after
# `cd tool && dune build`:
#
#     bash test_entry_invariant_merging.sh
#
# 1. Sizes after optimization.  F11, F12 and F13 contain two locations that
#    carry the same outgoing behaviour, except that the second is entered
#    only with a lower bound that the first does not have; they are merged
#    only if the guards are compared under the entry invariant.  F1 is a
#    control without such a pair.  Each row: id, expected optimized
#    locations, expected optimized transitions, optimized clocks.
# 2. Language: TChecker emptiness checks P1, P2 and S of run_tck_equivalence.sh
#    on the three formulas (skipped when TChecker is not installed).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
[ -x "$EXE" ] || { echo "missing $EXE (run: cd tool && dune build)"; exit 2; }
HDR=$("$EXE" -stats-header | tr '\t' ' ')
col() { echo "$HDR" | tr ' ' '\n' | grep -n -x "$1" | cut -d: -f1; }
CL=$(col opt_locs); CT=$(col opt_trans); CC=$(col opt_clocks)
fail=0
while IFS=$'\t' read -r id locs trans clocks; do
  formula=$(grep -v '^#' "$HERE/formulas.tsv" | awk -F'\t' -v id="$id" '$1==id {print $3}')
  d=$(mktemp -d)
  line=$(cd "$d" && "$EXE" -stats -nopdf -o t "$formula" 2>/dev/null | tail -1)
  rm -rf "$d"
  gl=$(echo "$line" | cut -f"$CL"); gt=$(echo "$line" | cut -f"$CT"); gc=$(echo "$line" | cut -f"$CC")
  if [ "$gl $gt $gc" = "$locs $trans $clocks" ]; then
    echo "ok   $id: $gl locations, $gt transitions, $gc clock(s)"
  else
    echo "FAIL $id: got $gl/$gt/$gc, expected $locs/$trans/$clocks"; fail=1
  fi
done <<'EOF'
F1	2	5	1
F11	3	4	1
F12	2	5	2
F13	2	3	1
EOF
if [ -x "$TCK" ]; then
  (cd "$HERE" && EXE="$EXE" TCK="$TCK" ONLY="F11 F12 F13" LIMIT=600 bash run_tck_equivalence.sh > /dev/null 2>&1)
  while IFS=$'\t' read -r id p1 p2 s c; do
    [ "$id" = id ] && continue
    if [ "$p1" = empty ] && [ "$p2" = empty ] && [ "$s" = empty ]; then
      echo "ok   $id: P1 P2 S empty"
    else
      echo "FAIL $id: P1=$p1 P2=$p2 S=$s"; fail=1
    fi
  done < "$HERE/tck_equivalence.tsv.only"
  rm -f "$HERE/tck_equivalence.tsv.only"
else
  echo "skip TChecker checks (not installed at $TCK)"
fi
exit $fail
