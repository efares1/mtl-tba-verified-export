#!/bin/bash
# N8 negated, alone: manual (-simp -spot-level any) then automatic mode.
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
OUT=$D/evaluation/n8_final.tsv
W=$(mktemp -d); cd $W
ulimit -v 9500000
f=$(awk -F'\t' '$1=="N8" {print $3}' $D/evaluation/formulas.tsv)
echo -e "config\tstatus\tseconds\tpeak_rss_kb\tfallback\tlocs\ttrans" > $OUT
for cfg in manual auto; do
  if [ $cfg = manual ]; then opts="-simp -spot-level any -spot-x ba-simul=0"; else opts=""; fi
  s=$(date +%s.%N)
  /usr/bin/time -f "%M" -o $W/mem timeout 1500 $EXE -nopdf -v -stats $opts -o r "!($f)" >$W/out 2>$W/err; rc=$?
  e=$(date +%s.%N)
  fb=$(grep -c "falling back" $W/err); line=$(tail -1 $W/out)
  st=ok; [ $rc -ne 0 ] && st=fail$rc
  printf "%s\t%s\t%.1f\t%s\t%s\t%s\t%s\n" $cfg $st "$(echo "$e - $s" | bc)" "$(tail -1 $W/mem)" $fb "$(echo "$line" | cut -f12)" "$(echo "$line" | cut -f13)" >> $OUT
done
touch $OUT.done
