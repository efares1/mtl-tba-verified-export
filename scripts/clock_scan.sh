#!/bin/bash
# Clocks, locations and transitions before (comp_) and after (opt_) optimization, per pattern.
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
hdr=$($EXE -stats-header)
col() { echo "$hdr" | tr '\t' '\n' | grep -n -x "$1" | cut -d: -f1; }
c1=$(col comp_clocks); c2=$(col opt_clocks); c3=$(col exp_clocks)
l1=$(col comp_locs); l2=$(col opt_locs); t1=$(col comp_trans); t2=$(col opt_trans)
W=$(mktemp -d); cd $W
printf "id\tneg_clocks:comp>opt>exp\tlocs:comp>opt\ttrans:comp>opt\n"
while IFS=$'\t' read -r id desc ours cas rest; do
  case "$id" in \#*|"") continue;; esac
  case "$id" in N6|N7|N8|R7|R8|N5|N4|F14) continue;; esac
  line=$(timeout 120 $EXE -nopdf -stats -o x "!($ours)" 2>/dev/null | tail -1)
  [ -z "$line" ] && { echo "$id timeout"; continue; }
  f() { echo "$line" | cut -f$1; }
  printf "%s\t%s>%s>%s\t%s>%s\t%s>%s\n" $id $(f $c1) $(f $c2) $(f $c3) $(f $l1) $(f $l2) $(f $t1) $(f $t2)
done < $D/evaluation/formulas.tsv
