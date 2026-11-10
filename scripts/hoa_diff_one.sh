#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$HOME/tool_copy/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
f=$(awk -F'\t' -v id="$1" '$1==id {print $3}' $D/evaluation/formulas.tsv)
$EXE -nopdf -spot-format lbtt -o l "!($f)" 2>/dev/null >/dev/null; $EXE -nopdf -spot-format hoa -o h "!($f)" 2>/dev/null >/dev/null
diff l.dot h.dot | head -30
