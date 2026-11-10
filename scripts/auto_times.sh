#!/bin/bash
# Automatic mode (default) on every pattern, positive and negated.
# Output: evaluation/auto_times.tsv (id pol status seconds fallback locs trans clocks)
# N8 negated is excluded (measured separately, alone).
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
LIM=${LIM:-120}
OUT=$D/evaluation/auto_times.tsv
W=$(mktemp -d); cd $W
ulimit -v 6000000
echo -e "id\tpol\tstatus\tseconds\tfallback\tlocs\ttrans\tclocks" > $OUT
grep -v '^#' $D/evaluation/formulas.tsv | cut -f1,3 | while IFS=$'\t' read id f; do
  for pol in pos neg; do
    [ "$id" = N8 ] && [ $pol = neg ] && continue
    if [ $pol = neg ]; then g="!($f)"; else g="$f"; fi
    s=$(date +%s.%N)
    timeout $LIM $EXE -nopdf -v -stats -o r "$g" >$W/out 2>$W/err; rc=$?
    e=$(date +%s.%N)
    fb=$(grep -c "falling back" $W/err)
    line=$(tail -1 $W/out)
    st=ok; [ $rc -ne 0 ] && st=fail
    printf "%s\t%s\t%s\t%.2f\t%s\t%s\t%s\t%s\n" $id $pol $st "$(echo "$e - $s" | bc)" $fb "$(echo "$line" | cut -f12)" "$(echo "$line" | cut -f13)" "$(echo "$line" | cut -f14)" >> $OUT
  done
done
touch $OUT.done
