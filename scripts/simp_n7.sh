#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
f=$(awk -F'\t' '$1=="N7" {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
s=$(date +%s.%N)
/usr/bin/time -f "maxrss %MKB" timeout 600 $EXE -nopdf -stats -simp -spot-level any -o r "!($f)" 2>mem.txt | tail -1 | cut -f1-4,12,13
e=$(date +%s.%N)
printf "N7 -simp any: %.1fs  %s\n" "$(echo "$e - $s" | bc)" "$(tail -1 mem.txt)"
