#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
get() { awk -F'\t' -v id="$1" '$1==id {print $3}' $D/evaluation/formulas.tsv; }
t() { local s=$(date +%s.%N); "$@" >/dev/null 2>$W/err; local e=$(date +%s.%N); printf "%.1f" $(echo "$e - $s" | bc); }
for id in F10 R7 N5 N6 N7; do
  f="!($(get $id))"
  ta=$(t $EXE -nopdf -v -o auto "$f"); fb=$(grep -c "falling back" $W/err)
  tx=$(t $EXE -nopdf -spot-level any -simp -o expl "$f")
  tl=$(t $EXE -nopdf -spot-level low -o low "$f")
  same_any=$(cmp -s auto.xml expl.xml && echo same || echo differs)
  same_low=$(cmp -s auto.xml low.xml && echo same || echo differs)
  echo "$id auto=${ta}s fallback=$fb | explicit any+simp=${tx}s (auto vs it: $same_any) | explicit low=${tl}s (auto vs it: $same_low)"
done
