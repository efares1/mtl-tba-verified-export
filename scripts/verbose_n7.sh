#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
f=$(awk -F'\t' '$1=="N7" {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
start=$(date +%s.%N)
$EXE -nopdf -v -simp -spot-level any -o r "!($f)" 2>&1 | while IFS= read -r line; do
  now=$(date +%s.%N)
  printf "%6.1fs  %s\n" "$(echo "$now - $start" | bc)" "$(echo "$line" | cut -c1-110)"
done | grep -v "^ *[0-9.]*s  *$" | tail -25
ls -l r.xml r.dot | awk '{print $5, $9}'
