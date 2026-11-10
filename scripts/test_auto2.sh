#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$HOME/tool_copy/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
get() { awk -F'\t' -v id="$1" '$1==id {print $3}' $D/evaluation/formulas.tsv; }
t() { local s=$(date +%s.%N); "$@" >/dev/null 2>$W/err; local e=$(date +%s.%N); printf "%.1f" $(echo "$e - $s" | bc); }
for id in N5 N6 N7; do
  f="!($(get $id))"
  ta=$(t $EXE -nopdf -v -o auto "$f"); fb=$(grep -c "falling back" $W/err)
  tm=$(t $EXE -nopdf -simp -spot-level any -spot-x ba-simul=0 -o man "$f")
  echo "$id auto=${ta}s (fallback=$fb)  manual any,simp,ba-simul=0=${tm}s  sizes: $(grep -c . /dev/null)"
done
