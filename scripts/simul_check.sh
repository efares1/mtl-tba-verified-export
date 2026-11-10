#!/bin/bash
# Effect of Spot's simulation reductions (-x ba-simul=0) on time and on the size of our output.
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
LIM=${LIM:-40}
OUT=$D/evaluation/simul_check.tsv
W=$(mktemp -d); cd $W
ulimit -v 6000000
echo -e "id\tpol\tcfg\tspotx\tstatus\tseconds\tlocs\ttrans" > $OUT
grep -v '^#' $D/evaluation/formulas.tsv | cut -f1,3 | while IFS=$'\t' read id f; do
  [ "$id" = N8 ] && continue
  for pol in pos neg; do
    if [ $pol = neg ]; then g="!($f)"; else g="$f"; fi
    for cfg in low any; do
      if [ $cfg = low ]; then opts="-spot-level low"; else opts="-simp -spot-level any"; fi
      for x in none ba-simul=0; do
        xo=""; [ $x != none ] && xo="-spot-x $x"
        s=$(date +%s.%N)
        line=$(timeout $LIM $EXE -nopdf -stats $opts $xo -o r "$g" 2>/dev/null | tail -1)
        e=$(date +%s.%N)
        st=ok; [ -z "$line" ] && st=fail
        printf "%s\t%s\t%s\t%s\t%s\t%.2f\t%s\t%s\n" $id $pol $cfg $x $st "$(echo "$e - $s" | bc)" "$(echo "$line" | cut -f12)" "$(echo "$line" | cut -f13)" >> $OUT
      done
    done
  done
done
touch $OUT.done
