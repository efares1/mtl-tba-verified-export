#!/bin/bash
# Does printing cubes (lbtt) cost time in Spot?  Compare output formats on the clocked formula.
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
id=${1:-N6}
W=$(mktemp -d); cd $W
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
$EXE -nopdf -v -simp -spot-level any -n 0 -o r "!($f)" 2>err >/dev/null
grep "^.*clocked LTL:" err | sed 's/.*clocked LTL: //' > f.ltl
echo "formula bytes: $(wc -c < f.ltl)"
for fmt in "--lbtt=t" "--hoa" "--hoa=t" "--spin"; do
  s=$(date +%s.%N); ltl2tgba -B --any $fmt -F f.ltl > out.txt 2>/dev/null; e=$(date +%s.%N)
  printf "%-10s %6.2f s  output %8d bytes %8d lines\n" "$fmt" "$(echo "$e - $s" | bc)" $(wc -c < out.txt) $(wc -l < out.txt)
done
s=$(date +%s.%N); ltl2tgba -B --any --stats='%s states %e edges' -F f.ltl > st.txt 2>/dev/null; e=$(date +%s.%N)
printf "stats only %6.2f s  (%s)\n" "$(echo "$e - $s" | bc)" "$(cat st.txt)"
