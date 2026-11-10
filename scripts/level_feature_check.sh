#!/bin/bash
# Time both Spot settings on every pattern, positive and negated, with a timeout.
# Output: evaluation/level_feature_check.tsv (id pol config status seconds trans)
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
LIM=${LIM:-30}
OUT=$D/evaluation/level_feature_check.tsv
W=$(mktemp -d); cd $W
ulimit -v 6000000
echo -e "id\tpol\tconfig\tstatus\tseconds\ttrans" > $OUT
grep -v '^#' $D/evaluation/formulas.tsv | cut -f1,3 | while IFS=$'\t' read id f; do
  for pol in pos neg; do
    if [ $pol = neg ]; then g="!($f)"; else g="$f"; fi
    for cfg in low any; do
      if [ $cfg = low ]; then opts="-spot-level low"; else opts="-simp -spot-level any -spot-x ba-simul=0"; fi
      s=$(date +%s.%N)
      line=$(timeout $LIM $EXE -nopdf -stats $opts -o r "$g" 2>/dev/null | tail -1); rc=$?
      e=$(date +%s.%N)
      st=ok; [ -z "$line" ] && st=fail
      printf "%s\t%s\t%s\t%s\t%.2f\t%s\n" $id $pol $cfg $st "$(echo "$e - $s" | bc)" "$(echo "$line" | cut -f13)" >> $OUT
    done
  done
done
echo done >> $OUT.done
