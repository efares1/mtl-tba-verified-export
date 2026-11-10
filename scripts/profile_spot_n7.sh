#!/bin/bash
# Where does Spot spend its time on the simplified clocked formula of a pattern?
# usage: profile_spot_n7.sh ID [level]
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
id=${1:-N7}; lvl=${2:-any}
W=$(mktemp -d); cd $W
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
$EXE -nopdf -v -simp -spot-level any -n 0 -o r "!($f)" 2>err >/dev/null &
pid=$!; sleep 2; kill $pid 2>/dev/null; wait $pid 2>/dev/null
grep "clocked LTL:" err | sed 's/.*clocked LTL: //' > f.ltl
echo "$id formula bytes $(wc -c < f.ltl)"
which perf >/dev/null 2>&1 && echo "perf available" || echo "perf NOT available"
which valgrind gprof 2>/dev/null
ltl2tgba --version | head -1
/usr/bin/time -f "plain: wall %es user %Us maxrss %MKB" ltl2tgba -B --$lvl -x ba-simul=0 --hoa -F f.ltl > o.hoa 2> t.txt; tail -1 t.txt
cp f.ltl $D/evaluation/spot_formula_$id.ltl
