#!/bin/bash
# Total time and size of the negation, current tool, for ids given as arguments.
# Uses -simp -spot-level any.  usage: final_times.sh ID...
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
for id in "$@"; do
  f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
  s=$(date +%s.%N)
  line=$(timeout 900 $EXE -nopdf -stats -simp -spot-level any -o r "!($f)" 2>/dev/null | tail -1)
  e=$(date +%s.%N)
  printf "%-4s total=%7.1fs  spot=%s opt=%s exp=%s  locs=%s trans=%s\n" $id "$(echo "$e - $s" | bc)" \
    "$(echo "$line" | cut -f4)" "$(echo "$line" | cut -f17)" "$(echo "$line" | cut -f18)" \
    "$(echo "$line" | cut -f12)" "$(echo "$line" | cut -f13)"
done
