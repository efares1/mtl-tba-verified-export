#!/bin/bash
# Time of the front end (everything but optimization and export): -compile-only.
# usage: frontend_time.sh ID [options]
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; shift
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
echo "stats header: $($EXE -stats-header | cut -f1-8 | tr '\t' ' ')"
s=$(date +%s.%N)
$EXE -nopdf -compile-only -stats "$@" -o r "!($f)" 2>/dev/null | tail -1 | tr '\t' ' '
e=$(date +%s.%N)
printf "wall %.1fs\n" "$(echo "$e - $s" | bc)"
# time to produce the clocked-LTL text only, via -check (stops after Spot, so subtract)
s=$(date +%s.%N)
$EXE -nopdf -check chk "$@" -o r "!($f)" >/dev/null 2>&1
e=$(date +%s.%N)
printf "with -check (full run): %.1fs\n" "$(echo "$e - $s" | bc)"
