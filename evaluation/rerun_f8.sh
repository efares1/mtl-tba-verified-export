#!/bin/bash
# Re-run of the evaluation on the configurations changed by the rewriting
# recur (default since v1.7; only F8 among the benchmark configurations) and
# on the random formulas whose automaton changes.  Run in WSL from this folder.
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
export ONLY="F8"
bash run_full_eval.sh
rm -f machine.only.txt ours_results.only.tsv
python3 merge_rows.py ours_runs.tsv spot_det.tsv
python3 summarize_runs.py
bash run_spot_validation.sh
bash run_interface_check.sh
bash run_tck_equivalence.sh
python3 merge_rows.py spot_validation.tsv interface_check.tsv tck_equivalence.tsv
unset ONLY
# random formulas whose exported automaton differs with -norecur
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
W=$(mktemp -d)
changed=""
grep -v '^#' random_formulas.tsv | while IFS=$'\t' read -r id ours cas; do
  [ -z "$id" ] && continue
  for g in "$ours" "!($ours)"; do
    a=$(cd "$W" && timeout 120 "$EXE" -nopdf -o a "$g" 2>/dev/null | sed 's/ -> .*//; s/.*: //')
    b=$(cd "$W" && timeout 120 "$EXE" -nopdf -norecur -o b "$g" 2>/dev/null | sed 's/ -> .*//; s/.*: //')
    if [ "$a" != "$b" ]; then echo "$id"; break; fi
  done
done | sort -u > "$W/changed"
echo "random formulas changed by recur: $(tr '\n' ' ' < "$W/changed")"
cp "$W/changed" random_changed_by_recur.txt
for id in $(cat "$W/changed"); do
  ONLY=$id OUT=/tmp/rd_$id.tsv bash run_random_diff.sh > /dev/null 2>&1
  tail -1 /tmp/rd_$id.tsv
done > random_diff.only.body
{ head -1 random_diff.tsv; cat random_diff.only.body; } > random_diff.tsv.only
rm -f random_diff.only.body
python3 merge_rows.py random_diff.tsv
rm -rf "$W"
echo done
