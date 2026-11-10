#!/bin/bash
# Install the regenerated optim.ml, rebuild, and check that the new binary writes
# byte-identical XML/DOT to the previous one on the benchmark formulas.
# usage: compare_old_new.sh
D=/mnt/c/Users/user/Desktop/JSS_paper
OLD=$HOME/mtl2tba_old.exe
NEW=$D/tool/_build/default/src/mtl2tba.exe
[ -f $OLD ] || cp $NEW $OLD
if ! cmp -s $D/proof/optim.ml $D/tool/src/optim.ml; then
  cp $D/tool/src/optim.ml $HOME/optim_previous.ml
  cp $D/proof/optim.ml $D/tool/src/optim.ml
fi
bash $D/scripts/build_tool.sh | head -5
W=$(mktemp -d); cd $W
same=0; diff=0
while IFS=$'\t' read -r id desc ours cas rest; do
  case "$id" in \#*|"") continue;; esac
  case "$id" in N6|N7|N8|R7|R8) continue;; esac
  for variant in neg pos; do
    if [ $variant = neg ]; then f="!($ours)"; else f="$ours"; fi
    [ $variant = pos ] && case "$id" in R5|R6|N5|N4|N3|F14) continue;; esac
    for n in "" "-n 1"; do
      timeout 200 $OLD -nopdf $n -o o_$id "$f" >/dev/null 2>o_$id.err; r1=$?
      timeout 200 $NEW -nopdf $n -o n_$id "$f" >/dev/null 2>n_$id.err; r2=$?
      if [ $r1 = $r2 ] && cmp -s o_$id.xml n_$id.xml && cmp -s o_$id.dot n_$id.dot && cmp -s o_$id.err n_$id.err; then same=$((same+1))
      else diff=$((diff+1)); echo "DIFF $id $variant [$n] rc=$r1/$r2"; fi
    done
  done
done < $D/evaluation/formulas.tsv
echo "identical: $same  different: $diff"
