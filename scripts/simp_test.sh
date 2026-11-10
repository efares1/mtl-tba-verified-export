#!/bin/bash
# Effect of -simp (and -spot-level) on the size of the clocked-LTL formula and the total time.
# usage: simp_test.sh ID
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
for opts in "" "-simp"; do
  for lvl in low any; do
    $EXE -nopdf -check chk $opts -spot-level $lvl -o r "!($f)" > /dev/null 2>&1
    sz=$(wc -c < chk_ltl.lbt)
    s=$(date +%s.%N)
    $EXE -nopdf -stats $opts -spot-level $lvl -o r "!($f)" > st.txt 2>/dev/null
    e=$(date +%s.%N)
    printf "%-8s %-4s ltl=%7d bytes  total=%6.2fs  %s\n" "[$opts]" $lvl $sz "$(echo "$e - $s" | bc)" "$(tail -1 st.txt | cut -f12,13)"
  done
done
