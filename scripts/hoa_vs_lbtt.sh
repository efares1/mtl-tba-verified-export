#!/bin/bash
# The tool reading Spot's HOA output against its LBTT output: same XML, DOT and messages?
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$HOME/tool_copy/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
same=0; diff=0; reord=0
while IFS=$'\t' read -r id desc ours cas rest; do
  case "$id" in \#*|"") continue;; esac
  case "$id" in N6|N7|N8|R7|R8) continue;; esac
  for variant in neg pos; do
    if [ $variant = neg ]; then f="!($ours)"; else f="$ours"; fi
    [ $variant = pos ] && case "$id" in R5|R6|N5|N4|N3|F14) continue;; esac
    for lvl in low any; do
      for n in "" "-n 1"; do
        timeout 200 $EXE -nopdf -spot-level $lvl -spot-format lbtt $n -o l_$id "$f" >/dev/null 2>l_$id.err; r1=$?
        timeout 200 $EXE -nopdf -spot-level $lvl -spot-format hoa $n -o h_$id "$f" >/dev/null 2>h_$id.err; r2=$?
        if [ $r1 = $r2 ] && cmp -s l_$id.xml h_$id.xml && cmp -s l_$id.dot h_$id.dot && cmp -s l_$id.err h_$id.err; then same=$((same+1))
        elif [ $r1 = $r2 ] && cmp -s l_$id.err h_$id.err && [ "$(tr -c 'A-Za-z0-9_' '
' < l_$id.xml | grep -v '^$' | sort | md5sum)" = "$(tr -c 'A-Za-z0-9_' '
' < h_$id.xml | grep -v '^$' | sort | md5sum)" ] && [ "$(tr -c 'A-Za-z0-9_' '
' < l_$id.dot | grep -v '^$' | sort | md5sum)" = "$(tr -c 'A-Za-z0-9_' '
' < h_$id.dot | grep -v '^$' | sort | md5sum)" ]; then reord=$((reord+1))
        else diff=$((diff+1)); echo "DIFF $id $variant $lvl [$n] rc=$r1/$r2 xml:$(cmp -s l_$id.xml h_$id.xml && echo same || echo differ) err:$(cmp -s l_$id.err h_$id.err && echo same || echo differ)"; fi
      done
    done
  done
done < $D/evaluation/formulas.tsv
echo "identical: $same  equal up to the order of guard conjuncts: $reord  different: $diff"
